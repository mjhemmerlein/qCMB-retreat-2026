# MAGs Practice Steps

Modular, step-by-step version of `reads_to_MAGs_pipeline.py` broken into individual shell scripts. Within-sample dRep has been removed — dereplication happens once, cross-sample, in step 09.

Each script has a SLURM header built in and can be submitted directly with `sbatch`. Scripts also contain skip logic so that if a job fails partway through, re-running it picks up where it left off rather than restarting the whole step.

---

## Directory structure

All scripts and `sample_list.txt` must live in the **same folder** — the scripts directory. This is defined as `SCRIPTS_DIR` in `00_config.sh` and is where the config looks for your sample list.

```
Project_directory/
├── scripts/                         ← all .sh files and sample_list.txt go here
│   ├── 00_config.sh
│   ├── 00b_init_metadata.sh
│   ├── 00c_raw_qc.sh
│   ├── 01_trim.sh
│   ├── ...
│   └── sample_list.txt              ← one sample name per line
├── raw_reads/                       ← {SAMPLE}_R1_001.fastq.gz files
├── pipeline_metadata.tsv            ← auto-generated, fills in as steps run
├── sample_MAG_database_mapping_summary.tsv
├── fastqc_raw/
├── cross_sample_dRep/
├── cross_sample_bowtie_DB/
├── coverm_output/
├── coassemblies/                    ← co-assemblies by treatment group
│   ├── scripts/
│   │   ├── control_list.txt         ← sample names for control co-assembly
│   │   └── carnitine_list.txt       ← sample names for carnitine co-assembly
│   ├── control/
│   │   ├── concatenated_reads/
│   │   └── megahit_out/
│   └── carnitine/
│       ├── concatenated_reads/
│       └── megahit_out/
└── {SAMPLE}/                        ← one directory per sample, auto-created
    ├── trimmed_reads/
    ├── megahit_out/
    ├── MAGs/
    ├── gtdb_v2.7.0_r232/
    ├── MAG_db_mapping/
    └── singlem_output/
```

---

## Setup

### 1. Edit `00_config.sh`

This is the only file you should need to edit. Everything else derives from it.

At minimum, update:
- `PROJECT_DIR` — root directory for the project
- `RAW_DIR` — where your raw `.fastq.gz` files live (default: `{PROJECT_DIR}/raw_reads`)
- `SCRIPTS_DIR` — where all scripts and `sample_list.txt` live (default: `{PROJECT_DIR}/scripts`)
- `--mail-user` in every script header — change to your email address

### 2. Fix the hardcoded config path in every script

When SLURM runs a script it copies it to a temp directory, which breaks `$(dirname "$0")`. Every script therefore has the config path hardcoded. If your scripts directory differs from the default, update this line in every script:

```bash
source "/home/projects-phoenix/ApoE_Carnitine/MetaG/scripts/00_config.sh"
```

The fastest way to update all at once:

```bash
cd /your/scripts/directory
sed -i 's|/home/projects-phoenix/ApoE_Carnitine/MetaG/scripts|/your/scripts/directory|g' \
    00b_init_metadata.sh 00c_raw_qc.sh 01_trim.sh 02_assemble.sh \
    03_filter_contigs.sh 04_map_to_contigs.sh 05_metabat.sh 06_checkm2.sh \
    07_gtdbtk.sh 08_cleanup.sh 09_cross_drep.sh 10_bowtie2_map.sh 11_coverm.sh
```

### 3. Generate `sample_list.txt`

The config reads sample names automatically from `sample_list.txt` in the scripts directory. Generate it from your raw read filenames:

```bash
ls /home/projects-phoenix/ApoE_Carnitine/MetaG/raw_reads/*_R1_001.fastq.gz | \
    xargs -n1 basename | \
    sed 's/_R1_001\.fastq\.gz//' \
    > /home/projects-phoenix/ApoE_Carnitine/MetaG/scripts/sample_list.txt
```

Then remove any controls or undetermined files that should not be processed:

```bash
sed -i '/Undetermined_S0/d' sample_list.txt
sed -i '/blank_1/d' sample_list.txt
sed -i '/^N$/d' sample_list.txt   # adjust pattern to match your negative control name
```

Verify it looks right before continuing:

```bash
cat sample_list.txt
```

The sample name is everything before `_R1_001.fastq.gz` in your filenames. For example, if your file is `con1_c1r_R1_001.fastq.gz`, the sample name is `con1_c1r`.

### 4. Initialize the metadata file

```bash
sbatch 00b_init_metadata.sh
```

---

## Running the pipeline

Scripts are submitted in order. Each reads `sample_list.txt` automatically via `00_config.sh` — you do not need to pass sample names unless overriding (e.g. `sbatch 01_trim.sh con1_c1r` to re-run one sample).

---

### Step 1 — Raw read QC (`00c_raw_qc.sh`)

Counts raw read pairs and total Gbp per sample, runs FastQC on raw reads, and generates a MultiQC summary across all samples. Populates `raw_reads` and `RAW_GBP_SEQ` columns in `pipeline_metadata.tsv`.

```bash
sbatch 00c_raw_qc.sh
```

---

### Step 2 — Trim reads (`01_trim.sh`)

Quality-trims raw reads with sickle, then removes adapter sequences and poly-G tails with bbduk. Poly-G trimming is essential for NextSeq/NovaSeq data due to 2-color chemistry artifacts. Final trimmed reads are written as `{SAMPLE}_R1_trimmed_noplyG.fastq` and `{SAMPLE}_R2_trimmed_noplyG.fastq`. Populates `trimmed_reads` and `TRIMMED_GBP_SEQ` in metadata.

```bash
sbatch 01_trim.sh
```

---

### Step 3 — Assembly (`02_assemble.sh`)

Assembles trimmed paired-end reads into contigs using MEGAHIT with a k-mer range of 31–121 (step 10). Output is `megahit_out/final.contigs.fa` per sample.

```bash
sbatch 02_assemble.sh
```

---

### Step 4 — Filter contigs (`03_filter_contigs.sh`)

Removes contigs shorter than 2500 bp using pullseq — short contigs are too small to bin reliably. Also runs `contig_stats.pl` to compute assembly statistics (N50, longest contig, total length) on both the raw and filtered assemblies. Populates `CONTIGS_ASSEMBLY`, `CONTIGS_GT2500`, `N50`, and `longest_contig` in metadata.

```bash
sbatch 03_filter_contigs.sh
```

---

### Step 5 — Map reads to contigs (`04_map_to_contigs.sh`)

Maps trimmed reads back to filtered contigs using BBMap to generate per-contig coverage depth needed for binning. Pipeline: BBMap → SAM → BAM → coordinate sort → reformat.sh identity filter (≥99%, paired-only, primary-only). The filtered sorted BAM (`*_mapped99per.sorted.bam`) is passed to MetaBAT in the next step.

```bash
sbatch 04_map_to_contigs.sh
```

---

### Step 6 — Bin contigs (`05_metabat.sh`)

Clusters filtered contigs into metagenome-assembled genome (MAG) bins using MetaBAT, which uses both tetranucleotide frequency and the coverage depth signal from the BAM produced in step 5. Output bins are written as `.fa` files to `{SAMPLE}_2500.fa.metabat-bins/`.

```bash
sbatch 05_metabat.sh
```

---

### Step 7 — MAG quality control (`06_checkm2.sh`)

Assesses completeness and contamination of each bin using CheckM2. Bins passing thresholds (completeness ≥50%, contamination ≤10%) are copied into `{SAMPLE}/MAGs/` with the sample name prepended to the filename. Populates `bins` and `MQHQ_bins` in metadata.

```bash
sbatch 06_checkm2.sh
```

---

### Step 8 — Taxonomy assignment (`07_gtdbtk.sh`) and cleanup (`08_cleanup.sh`)

These two steps are independent and can be run in either order after step 7.

`07_gtdbtk.sh` assigns taxonomy to all MQ/HQ MAGs in `{SAMPLE}/MAGs/` using GTDB-Tk v2.7.1 against the r232 database. Output is written to `{SAMPLE}/gtdb_v2.7.0_r232/`.

`08_cleanup.sh` deletes intermediate mapping files from step 5 (SAM, unsorted BAM, filtered BAM) to free disk space, and gzip-compresses the raw unsorted BAM as an archive.

```bash
sbatch 07_gtdbtk.sh
sbatch 08_cleanup.sh
```

---

### Step 9 — Cross-sample dereplication (`09_cross_drep.sh`)

Pools all MQ/HQ MAGs from every sample's `MAGs/` directory and runs dRep once across all of them, producing a single non-redundant MAG catalog (153 primary clusters from 569 input MAGs for this dataset). Contig headers are renamed with `rename_bins_like_dram.py` for DRAM compatibility, and all dereplicated MAGs are concatenated into one shared FASTA (`all_samples_derep_MAGs.fa`) that serves as the mapping reference for steps 10–11.

```bash
sbatch 09_cross_drep.sh
```

---

### Step 10 — Cross-sample read mapping (`10_bowtie2_map.sh`)

Builds a single Bowtie2 index from the cross-sample MAG database, then maps each sample's trimmed reads to that shared reference. For each sample: Bowtie2 → SAM → BAM → reformat.sh identity filter (≥99%, paired-only, primary-only) → position-sorted BAM (POSSORT). All POSSORT BAMs are written to `possort_bam_list.txt` for use by CoverM. Mapping rates per sample are written to `sample_MAG_database_mapping_summary.tsv` and to metadata.

```bash
sbatch 10_bowtie2_map.sh
```

---

### Step 11 — Between-sample abundance (`11_coverm.sh`)

Runs CoverM once with all samples' POSSORT BAMs against the cross-sample MAG database, producing three abundance tables — all samples as columns, MAGs as rows — enabling direct between-sample comparisons:

- `coverm_reads_per_base.txt` — raw read depth normalized by genome length, no breadth filter
- `coverm_min75.txt` — same, but only reports MAGs where ≥75% of the genome is covered (filters spurious hits)
- `coverm_trimmed_mean.txt` — trimmed mean coverage, robust to outliers

```bash
sbatch 11_coverm.sh
```

---

### Step 12 — Co-assembly (`02b_coassemble.sh`)

**Why:** Per-sample assembly can miss low-abundance organisms present across multiple samples but below the depth threshold needed to assemble from any single sample alone. Co-assembly pools trimmed reads from all samples within a treatment group and runs one MEGAHIT job, increasing effective coverage depth and producing longer, more complete contigs for shared organisms. The meaningful quality indicator is N50 improvement, not contig count — co-assembly collapses redundancy across samples (single-sample N50 ~4 kbp → co-assembly N50 ~8.7 kbp for this dataset).

**When:** Run after step 10 was complete for all ApoE_Carnitine samples.

**Setup required before running:** The `coassemblies/` directory structure and sample list files were created manually:

```
coassemblies/
├── scripts/
│   ├── control_list.txt      ← one sample name per line
│   └── carnitine_list.txt    ← one sample name per line
├── control/
└── carnitine/
```

**What it does:** For each group, concatenates trimmed R1 reads from all listed samples into one R1 FASTQ (and same for R2), then runs MEGAHIT on the concatenated reads. Both groups are processed in a single job submission. Exits hard if any sample's trimmed reads are missing — all samples must be present for a valid co-assembly.

**Groups and samples:**
- **control**: con1_c1r_S1, con2_c2l_S2, con3_c3r_S3, con4_c4l_S4, con5_c6nn_S5
- **carnitine**: carn1_c7r_S6, carn2_c8l_S7, carn3_c9r_S8, carn4_c10l_S9, carn5_c8nn_S10

**Output:**
```
coassemblies/{group}/concatenated_reads/{group}_R1_concat.fastq
coassemblies/{group}/concatenated_reads/{group}_R2_concat.fastq
coassemblies/{group}/megahit_out/final.contigs.fa
```

Co-assembly outputs are independent of the main per-sample pipeline. Downstream steps (contig filtering, binning, CheckM2) can be applied to the co-assembly FASTAs separately if needed. SingleM is not run on the co-assemblies — the reads-based SingleM profile plus `appraise` against the cross-sample dereplicated MAG set gives a more complete picture of recovery.

```bash
sbatch 02b_coassemble.sh
```

---

### Step 13 — Community profiling (`singleM_pipe.py` + `RUN_singleM_pipe.sh`)

**Why:** SingleM provides a reads-based community profile that is completely independent of assembly and binning. It uses conserved single-copy marker genes to classify reads directly, so low-abundance organisms and organisms that assemble poorly still appear. This is complementary to CoverM — CoverM quantifies abundance of MAGs you successfully recovered; SingleM tells you what was in the community in the first place and whether your recovery was complete.

**When:** Steps 1, 4, and 5 (reads pipe, prokaryotic fraction, summarise) were run on raw reads after per-sample steps were confirmed complete. Steps 2 and 3 (MAG pipe and appraise) are deferred until MAGs are available and the cross-sample dRep (step 9) is complete.

**Sample list:** Reads from `scripts/apoe_sample_list.txt` automatically. Can be overridden with `-s SAMPLE1,SAMPLE2`.

**What it does, step by step:**

**Step 13.1 — Pipe on raw reads** *(run now)*
Runs `singlem pipe` on raw reads (`_R1_001.fastq`, `_R2_001.fastq`). Output per sample:
- `{sample}_reads.otu_table.csv` — per-sequence OTU table with taxonomy for each marker gene hit
- `{sample}_reads.archive.otu_table.json.gz` — archive format required for re-running appraise or summarise without re-running pipe
- `{sample}_reads.profile.tsv` — community-level taxonomic profile; the primary output for relative abundance

**Step 13.2 — Pipe on MAGs** *(deferred — requires step 7)*
Runs `singlem pipe` on per-sample MAG FASTAs in `{SAMPLE}/MAGs/`. Output:
- `{sample}_MAGs.otu_table.csv`
- `{sample}_MAGs.profile.tsv`

**Step 13.3 — Appraise** *(deferred — requires step 13.2)*
Compares reads OTU table against MAG OTU table to identify community members not recovered in the MAG catalog. Output:
- `{sample}_appraise_unrecovered.csv` — OTUs present in reads but absent from MAGs

**Step 13.4 — Prokaryotic fraction** *(run now)*
Estimates the fraction of reads that are prokaryotic vs host (mouse) DNA. Output:
- `{sample}_prokaryotic_fraction.tsv`

**Step 13.5 — Summarise** *(run now)*
Summarises the reads profile at phylum level and generates a Krona chart. Output:
- `{sample}_phylum_relabun.csv` — phylum-level relative abundance table ready for R
- `{sample}_krona.html` — interactive Krona pie chart for visual QC

All output written to `{SAMPLE}/singlem_output/`.

```bash
sbatch RUN_singleM_pipe.sh
```

---

### Monitoring jobs

```bash
squeue -u $USER              # see running/pending jobs
squeue -u $USER -l           # more detail
watch -n 5 squeue -u $USER   # auto-refresh every 5 seconds
tail -f slurm_JOBID.out      # watch log in real time

# After a job finishes:
sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS
sacct -u $USER --format=JobID,JobName,State,ExitCode,Elapsed --starttime=today
```

---

## Script overview

Scripts run in the order listed. Steps 1–11 follow the numbered filenames. Steps 12–13 are additional analyses run after step 10 was complete.

| Step | Script | Resources | What it does |
|------|--------|-----------|--------------|
| — | `00_config.sh` | — | Shared config; sourced by every script. Edit this first. |
| — | `00b_init_metadata.sh` | 1 cpu, 1gb, 5min | Initialize `pipeline_metadata.tsv` with header row |
| 1 | `00c_raw_qc.sh` | 4 cpu, 50gb, 24hr | Count raw reads + Gbp; FastQC on raw reads; MultiQC summary |
| 2 | `01_trim.sh` | 10 cpu, 50gb, 24hr | sickle quality trim + bbduk adapter/poly-G removal |
| 3 | `02_assemble.sh` | 50 cpu, 450gb, 14 days | MEGAHIT per-sample assembly |
| 4 | `03_filter_contigs.sh` | 4 cpu, 50gb, 12hr | pullseq length filter (≥2500 bp) + contig_stats.pl |
| 5 | `04_map_to_contigs.sh` | 50 cpu, 450gb, 14 days | BBMap → SAM → BAM → sort → 99% identity filter |
| 6 | `05_metabat.sh` | 50 cpu, 200gb, 48hr | MetaBAT binning |
| 7 | `06_checkm2.sh` | 10 cpu, 100gb, 48hr | CheckM2 QC + filter and copy MQ/HQ MAGs |
| 8a | `07_gtdbtk.sh` | 20 cpu, 200gb, 14 days | GTDB-Tk taxonomy assignment (independent of 8b) |
| 8b | `08_cleanup.sh` | 1 cpu, 10gb, 6hr | Delete intermediate mapping files; compress raw BAM (independent of 8a) |
| 9 | `09_cross_drep.sh` | 50 cpu, 200gb, 48hr | Cross-sample dRep + rename contigs + build shared FASTA |
| 10 | `10_bowtie2_map.sh` | 50 cpu, 450gb, 14 days | Build shared Bowtie2 index; map all samples to it |
| 11 | `11_coverm.sh` | 15 cpu, 100gb, 24hr | Between-sample abundance: reads_per_base, min75, trimmed_mean |
| 12 | `02b_coassemble.sh` | 50 cpu, 450gb, 14 days | Pool trimmed reads by group and co-assemble with MEGAHIT |
| 13 | `singleM_pipe.py` | 20 cpu, 100gb, 48hr | SingleM on raw reads (steps 13.1, 13.4, 13.5 now; 13.2–13.3 deferred until MAGs ready) |

To override the sample list and re-run a single sample for any per-sample step:

```bash
sbatch 01_trim.sh con1_c1r_S1
sbatch 02_assemble.sh con1_c1r_S1 con2_c2l_S2
```

---

## Skip logic

If a job fails partway through, re-submitting it will skip any steps that already completed successfully. Here is what each script checks:

| Script | Skips if... |
|--------|-------------|
| `00c_raw_qc.sh` | `raw_reads` already filled in metadata AND FastQC HTML files exist |
| `01_trim.sh` | Final trimmed `.fastq` files already exist |
| `02_assemble.sh` | `final.contigs.fa` already exists (auto-removes incomplete MEGAHIT dir) |
| `03_filter_contigs.sh` | Filtered scaffolds `.fa` already exists |
| `04_map_to_contigs.sh` | `*_mapped99per.sorted.bam` already exists |
| `05_metabat.sh` | Bins directory exists and contains `.fa` files |
| `06_checkm2.sh` | CheckM2: `quality_report.tsv` exists. MAG copy: `MAGs/` has `.fa` files |
| `07_gtdbtk.sh` | `gtdbtk.*.summary.tsv` already exists in output directory |
| `08_cleanup.sh` | Always safe to re-run — only acts on files that exist |
| `09_cross_drep.sh` | dRep, rename, and concatenation each checked independently |
| `10_bowtie2_map.sh` | Bowtie2 index: `.bt2` files exist. Per-sample: POSSORT BAM exists |
| `11_coverm.sh` | Each of the three output files checked independently |

---

## Metadata file

`{PROJECT_DIR}/pipeline_metadata.tsv` is a tab-separated table with one row per sample, populated incrementally as steps complete. Columns not yet filled in are written as `NA`.

| Column | Populated by | Description |
|--------|-------------|-------------|
| `sample` | `00c_raw_qc.sh` | Sample name |
| `raw_reads` | `00c_raw_qc.sh` | Number of raw read pairs (R1 count) |
| `RAW_GBP_SEQ` | `00c_raw_qc.sh` | Total raw sequencing yield in Gbp (R1 + R2) |
| `trimmed_reads` | `01_trim.sh` | Number of trimmed read pairs |
| `TRIMMED_GBP_SEQ` | `01_trim.sh` | Total trimmed yield in Gbp (R1 + R2) |
| `CONTIGS_ASSEMBLY` | `03_filter_contigs.sh` | Total contigs in raw assembly |
| `CONTIGS_GT2500` | `03_filter_contigs.sh` | Contigs passing the 2500bp length filter |
| `N50` | `03_filter_contigs.sh` | N50 of filtered assembly |
| `longest_contig` | `03_filter_contigs.sh` | Length of longest contig in filtered assembly |
| `bins` | `06_checkm2.sh` | Total bins produced by MetaBAT |
| `MQHQ_bins` | `06_checkm2.sh` | Bins passing MQ/HQ thresholds (completeness >50%, contamination <10%) |
| `percent_reads_mapped` | `10_bowtie2_map.sh` | % trimmed read pairs mapped to cross-sample MAG database |

Check the metadata file at any point:

```bash
column -t /home/projects-phoenix/ApoE_Carnitine/MetaG/pipeline_metadata.tsv
```

---

## Notes

- **Raw read format**: both `.fastq` and `.fastq.gz` are handled automatically. The config detects which format is present. Trimmed reads are always written as plain `.fastq`.
- **poly-G trimming**: the bbduk step in `01_trim.sh` trims poly-G tails, which is essential for NextSeq 1000/2000 data due to 2-color chemistry artifacts.
- **Within-sample dRep removed**: the pipeline goes directly from per-sample MAGs → cross-sample dRep in step 09.
- **GTDB-Tk and cleanup are independent**: steps 07 and 08 can be run in either order after step 06.
- **Identity filter note**: `BOWTIE2_MIN_ID` (0.99) and `COVERM_MIN_ID` (0.97) are intentionally different. The reformat.sh filter in step 04 enforces 99% identity at the BAM level before CoverM sees the reads, making the CoverM identity parameter a secondary filter on already-filtered data. See `00_config.sh` for parameter details.
- **Tools required**: `fastqc` and `multiqc` must be in your PATH for step 00c. CheckM2 and GTDB-Tk are activated via conda environments inside their scripts.
- **Co-assembly**: run separately after step 10 using `02b_coassemble.sh`. Requires manually creating the `coassemblies/scripts/` directory and `control_list.txt` / `carnitine_list.txt` files before running. Output lives in `coassemblies/[control|carnitine]/` and is independent of the per-sample pipeline.
- **SingleM**: run on raw reads using `singleM_pipe.py` (submitted via `RUN_singleM_pipe.sh`). Steps 1, 4, and 5 (reads pipe, prokaryotic fraction, summarise) can be run any time after raw reads are available. Steps 2 and 3 (MAG pipe, appraise) must wait until MAGs are available from step 06 and the cross-sample dRep (step 09) is complete.
