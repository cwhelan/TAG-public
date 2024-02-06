version 1.0

workflow SingleSampleCODEC {
    input {
        String sample_id
        File fastq1
        File fastq2
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        File reference_pac
        File reference_amb
        File reference_ann
        File reference_bwt
        File reference_sa
        File germline_bam
        File germline_bam_index
        Int num_parallel
        String sort_memory
        File eval_genome_interval
    }
        call SplitFastq1 {
            input: 
                fastq_read1 = fastq1,
                nsplit = num_parallel,
                sample_id = sample_id
        }
        call SplitFastq2 {
            input: 
                fastq_read2 = fastq2,
                nsplit = num_parallel,
                sample_id = sample_id
        }
    scatter (split_index in range(num_parallel)) {
        String output_prefix = "${sample_id}_split.${split_index}"
        call Trim {
            input:
                read1 = SplitFastq1.split_read1[split_index],
                read2 = SplitFastq2.split_read2[split_index],
                output_prefix = output_prefix,
                split = split_index,
                sample_id = sample_id
        }
        call AlignRawTrimmed {
            input:
                bam_input = Trim.trimmed_bam,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict,
                reference_pac = reference_pac,
                reference_amb = reference_amb,
                reference_ann = reference_ann,
                reference_bwt = reference_bwt,
                reference_sa = reference_sa,
                sample_id = sample_id,
                split = split_index              
        }
        call ZipperBamAlignment {            
            input:
                mapped_bam = AlignRawTrimmed.aligned_bam,
                unmapped_bam = Trim.trimmed_bam,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict,
                sample_id = sample_id,
                split = split_index,
                sort_memory = sort_memory
            }
        }
        call MergeSplit {
            input:
                bam_files = ZipperBamAlignment.bam,
                sample_id = sample_id                               
        }     
        call MergeLogSplit {
            input:
                log_files = Trim.trimmed_log,
                sample_id = sample_id 
        }    
        call SortBam {
            input: 
                bam_file = MergeSplit.merged_bam,
                sample_id = sample_id                  
        }      
        call CDSByProduct {
            input:
                trim_log = MergeLogSplit.merged_log,
                highconf_bam = SortBam.sorted_bam,
                sample_id = sample_id                 
        }
        call ReplaceRawReadGroup {
            input: 
                raw_bam = MergeSplit.merged_bam,
                sample_id = sample_id
        }
        call MarkRawDuplicates {
            input:
                input_bam = ReplaceRawReadGroup.bam,
                sample_id = sample_id
        }
        call CollectInsertSizeMetrics {
            input:
                input_bam = MarkRawDuplicates.dup_marked_bam,
                sample_id = sample_id
        }
        call GroupReadByUMI {
            input:
                input_bam = MarkRawDuplicates.dup_marked_bam,
                sample_id = sample_id
        }
        call FgbioCollapseReadFamilies {
            input:
                grouped_umi_bam = GroupReadByUMI.groupbyumi_bam,
                sample_id = sample_id
        }
        call AlignMolecularConsensusReads {
            input:
                mol_consensus_bam = FgbioCollapseReadFamilies.mol_consensus_bam,
                sample_id = sample_id,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict,
                reference_pac = reference_pac,
                reference_amb = reference_amb,
                reference_ann = reference_ann,
                reference_bwt = reference_bwt,
                reference_sa = reference_sa
        }
        call MergeAndSortMoleculeConsensusReads {
            input:
                mapped_sam = AlignMolecularConsensusReads.aligned_bam,
                unmapped_bam = FgbioCollapseReadFamilies.mol_consensus_bam,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict,
                sample_id = sample_id,
                sort_memory = sort_memory
        }
        call CollectRawWgsMetrics {
            input:
                ReplaceRGBam = MarkRawDuplicates.dup_marked_bam,
                sample_id = sample_id,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict
        }
        call CollectConsensusWgsMetrics {
            input:
                ConsensusAlignedBam = MergeAndSortMoleculeConsensusReads.bam,
                ConsensusAlignedBai = MergeAndSortMoleculeConsensusReads.bai,
                sample_id = sample_id,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict
        }
        call CSS_SFC_ErrorMetrics {
            input:
                ConsensusAlignedBam = MergeAndSortMoleculeConsensusReads.bam,
                ConsensusAlignedBai = MergeAndSortMoleculeConsensusReads.bai,
                sample_id = sample_id,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict,
                reference_pac = reference_pac,
                reference_amb = reference_amb,
                reference_ann = reference_ann,
                reference_bwt = reference_bwt,
                reference_sa = reference_sa,
                germline_bam = germline_bam,
                germline_bam_index = germline_bam_index
        }
        call RAW_SFC_ErrorMetrics {
            input:
                ReplaceRGBam = MarkRawDuplicates.dup_marked_bam,
                ReplaceRGBai = MarkRawDuplicates.dup_marked_bai,
                sample_id = sample_id,
                reference_fasta = reference_fasta,
                reference_fasta_index = reference_fasta_index,
                reference_dict = reference_dict,
                reference_pac = reference_pac,
                reference_amb = reference_amb,
                reference_ann = reference_ann,
                reference_bwt = reference_bwt,
                reference_sa = reference_sa,
                germline_bam = germline_bam,
                germline_bam_index = germline_bam_index
        }
        call QC_metrics {
            input:
                byproduct_metrics = CDSByProduct.byproduct_metrics,
                RawWgsMetrics = CollectRawWgsMetrics.RawWgsMetrics,
                DuplicationMetrics = MarkRawDuplicates.dup_metrics,
                InsertSizeMetrics = CollectInsertSizeMetrics.insert_size_metrics,
                ConsensusWgsMetrics = CollectConsensusWgsMetrics.ConsensusWgsMetrics,
                mutant_metrics = CSS_SFC_ErrorMetrics.mutant_metrics,
        }
        call EvalGenomeBases {
             input: 
                eval_genome_interval = eval_genome_interval
        }
        call CalculateDuplexDepth {
             input: 
              eval_genome_bases = EvalGenomeBases.eval_genome_bases,
              n_bases_eval = QC_metrics.n_bases_eval
        }

    output {
        File byproduct_metrics = CDSByProduct.byproduct_metrics
        File RAW_BAM = MergeSplit.merged_bam
        File RAW_BAM_index = MergeSplit.merged_bai
        File MolConsensusBAM = MergeAndSortMoleculeConsensusReads.bam
        File MolConsensusBAM_index = MergeAndSortMoleculeConsensusReads.bai
        File InsertSizeMetrics = CollectInsertSizeMetrics.insert_size_metrics
        File InsertSizeHistogram = CollectInsertSizeMetrics.insert_size_histogram
        File DuplicationMetrics = MarkRawDuplicates.dup_metrics
        File RawWgsMetrics = CollectRawWgsMetrics.RawWgsMetrics
        File ConsensusWgsMetrics = CollectConsensusWgsMetrics.ConsensusWgsMetrics
        File raw_mutant_metrics = RAW_SFC_ErrorMetrics.raw_mutant_metrics
        File raw_context_count = RAW_SFC_ErrorMetrics.raw_context_count
        File raw_variants_called = RAW_SFC_ErrorMetrics.raw_variants_called
        File mutant_metrics = CSS_SFC_ErrorMetrics.mutant_metrics
        File context_count = CSS_SFC_ErrorMetrics.context_count
        File variants_called = CSS_SFC_ErrorMetrics.variants_called

        Int n_total_fastq = QC_metrics.n_total_fastq 
        Int n_correct_products = QC_metrics.n_correct_products
        Float pct_correct_products = QC_metrics.pct_correct_products
        Int n_double_ligation = QC_metrics.n_double_ligation
        Float pct_double_ligation = QC_metrics.pct_double_ligation
        Int n_intermol = QC_metrics.n_intermol
        Float pct_intermol = QC_metrics.pct_intermol
        Int n_adp_dimer = QC_metrics.n_adp_dimer
        Float pct_adp_dimer = QC_metrics.pct_adp_dimer 
        Float raw_dedupped_mean_cov = QC_metrics.raw_dedupped_mean_cov
        Int raw_dedupped_median_cov = QC_metrics.raw_dedupped_median_cov
        Float raw_duplication_rate = QC_metrics.raw_duplication_rate
        Float mean_insert_size = QC_metrics.mean_insert_size
        Int median_insert_size = QC_metrics.median_insert_size
        Float mol_consensus_mean_cov = QC_metrics.mol_consensus_mean_cov
        Int mol_consensus_median_cov = QC_metrics.mol_consensus_median_cov
        Int n_snv = QC_metrics.n_snv
        Int n_indel = QC_metrics.n_indel
        String n_bases_eval = QC_metrics.n_bases_eval   
        Float snv_rate = QC_metrics.snv_rate
        Float indel_rate = QC_metrics.indel_rate
        String eval_genome_bases = EvalGenomeBases.eval_genome_bases
        Float duplex_depth = CalculateDuplexDepth.duplex_depth
    }
}

task SplitFastq1 {
    input {
        File fastq_read1
        String sample_id
        Int nsplit
        Int memory = 64
        Int disk_size = 200
    }

    command <<<
        set -e
        
        zcat ~{fastq_read1} | /CODECsuite/snakemake/script/fastqsplit.pl ~{sample_id}_split_r1 ~{nsplit}

    >>>

    output {
        Array[File] split_read1 = glob("~{sample_id}_split_r1.*.fastq")
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1"
        memory: memory + " GB"
        disks: "local-disk " + disk_size + " HDD"
    }
}

task SplitFastq2 {
    input {
        File fastq_read2
        Int nsplit
        String sample_id
        Int memory = 64
        Int disk_size = 200
    }

    command <<<
        set -e
        zcat ~{fastq_read2} | /CODECsuite/snakemake/script/fastqsplit.pl ~{sample_id}_split_r2 ~{nsplit} 
        
    >>>

    output {
        Array[File] split_read2 = glob("~{sample_id}_split_r2.*.fastq")
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1"
        memory: memory + " GB"
        disks: "local-disk " + disk_size + " HDD"
    }
}

task Trim {
    input {
        File read1
        File read2
        String sample_id
        String output_prefix
        Int split
        Int mem = 16
        Int disk_size = 32
    }
        
    command {
        set -e 

        /CODECsuite/build/codec trim -1 ~{read1} -2 ~{read2} -o ~{output_prefix} -u 3 -U 3 -f 2 -t 2 -s ~{sample_id} > ~{output_prefix}.trim.log
    
    }
    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        memory: mem + " GB"
    }
    output {
        File trimmed_bam = "${sample_id}_split.${split}.trim.bam"
        File trimmed_log = "${sample_id}_split.${split}.trim.log"
    }
}

task AlignRawTrimmed {
    input {
        File bam_input
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        File reference_pac
        File reference_amb
        File reference_ann
        File reference_bwt
        File reference_sa
        Int? memory
        Int? disk
        Int mem = select_first([memory, 16]) 
        Int disk_size = select_first([disk, 32]) 
        String sample_id
        Int split
    }

    String output_bam_name = "${sample_id}_split.${split}.aligned_tmp.bam"

    command {
        samtools fastq ~{bam_input} | \
        bwa mem \
            -K 100000000 \
            -p \
            -Y \
            ~{reference_fasta} - | samtools view - -S -b -o ~{output_bam_name} 
    }

    output {
        File aligned_bam = output_bam_name
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1"
        memory: mem + " GB"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 3
    }
}

task ZipperBamAlignment {
    input {
        File mapped_bam
        File unmapped_bam
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        Int? mem
        Int? disk_size
        String sample_id
        Int split
        String sort_memory

    }

    String bamOutput = "${sample_id}_split.${split}.trim.aligned.bam"
    String baiOutput = "${sample_id}_split.${split}.trim.aligned.bam.bai"

    command {
        java -jar /dependencies/fgbio-2.0.2.jar --compression 0 --async-io ZipperBams \
            -i ~{mapped_bam} \
            --unmapped ~{unmapped_bam} \
            --ref ~{reference_fasta} \
        | samtools sort -m ~{sort_memory} - -o ~{bamOutput} -O BAM && samtools index ~{bamOutput}
    }

    output {
        File bam = bamOutput
        File bai = baiOutput
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        memory: select_first([mem, 8]) + " GB"
        disks: "local-disk " + select_first([disk_size, 16]) + " HDD"
        preemptible: 3
    }
}

task MergeSplit {
    input {
        Array[File] bam_files
        String sample_id
        Int memory = 64
        Int disk_size =200
    }

    command {
        set -e
        samtools merge -@ 4 ~{sample_id}.raw.aligned.bam ~{sep=' ' bam_files} && \
        samtools index ~{sample_id}.raw.aligned.bam
    }

    output {
        File merged_bam = "~{sample_id}.raw.aligned.bam"
        File merged_bai = "~{sample_id}.raw.aligned.bam.bai"
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        memory: memory + " GB"
    }
}

task MergeLogSplit {
    input {
        Array[File] log_files
        String sample_id
        Int mem = 32
        Int disk_size = 64
    }

    command {
        set -e
        python3 /CODECsuite/snakemake/script/agg_log.py ~{sep=' ' log_files} ~{sample_id}.trim.log
    }

    output {
        File merged_log = "~{sample_id}.trim.log"
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        memory: mem + " GB"
    }
}

task SortBam {
    input {
        File bam_file
        String sample_id
        Int mem = 64
        Int disk_size = 200
    }

    command {
        samtools sort -n ~{bam_file} -o ~{sample_id}.raw.aligned.sortbyname.bam
    }

    output {
        File sorted_bam = "~{sample_id}.raw.aligned.sortbyname.bam"
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        memory: mem + " GB"
        preemptible: 2
    }
}

task CDSByProduct {
    input {
        File trim_log
        File highconf_bam
        String sample_id
        Int mem = 32
        Int disk_size = 100
    }

    command {
        python3 /CODECsuite/snakemake/script/cds_summarize.py --sample_id ~{sample_id} --trim_log ~{trim_log} \
        --highconf_bam ~{highconf_bam} > ~{sample_id}.byproduct.txt
    }

    output {
        File byproduct_metrics = "~{sample_id}.byproduct.txt"
    }

    runtime {
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        memory: mem + " GB"
    }
}

task ReplaceRawReadGroup {
    input {
        File raw_bam
        String sample_id
        Int memory = 64
        Int disk_size = 200
    }

    command {
        java -jar /dependencies/picard.jar AddOrReplaceReadGroups \
            I=~{raw_bam} \
            O=~{sample_id}.raw.replacerg.bam \
            CREATE_INDEX=true \
            RGID=4 \
            RGLB=lib1 \
            RGPL=ILLUMINA \
            RGPU=unit1 \
            RGSM=~{sample_id}
    }

    output {
        File bam = "~{sample_id}.raw.replacerg.bam"
        File bai = "~{sample_id}.raw.replacerg.bai"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
    }
}

task MarkRawDuplicates {
    input {
        File input_bam
        String sample_id
        Int memory = 64
        Int disk_size = 200
    }

    command {
        java -jar /dependencies/picard.jar MarkDuplicates \
            I=~{input_bam} \
            O=~{sample_id}.raw.replacerg.markdup.bam \
            M=~{sample_id}.raw.marked_duplicates.txt \
            CREATE_INDEX=true \
            TAG_DUPLICATE_SET_MEMBERS=true \
            TAGGING_POLICY=All
            
        samtools index ~{sample_id}.raw.replacerg.markdup.bam
    }

    output {
        File dup_marked_bam = "~{sample_id}.raw.replacerg.markdup.bam"
        File dup_marked_bai = "~{sample_id}.raw.replacerg.markdup.bam.bai"
        File dup_metrics = "~{sample_id}.raw.marked_duplicates.txt"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
    }
}

task CollectInsertSizeMetrics {
    input {
        File input_bam
        String sample_id
        Int memory = 32
        Int disk_size = 200
    }

    command {
        java -jar /dependencies/picard.jar CollectInsertSizeMetrics \
            I=~{input_bam} \
            O=~{sample_id}.raw.insert_size_metrics.txt \
            H=~{sample_id}.raw.insert_size_histogram.pdf \
            M=0.5 W=600 DEVIATIONS=100
    }

    output {
        File insert_size_metrics = "~{sample_id}.raw.insert_size_metrics.txt"
        File insert_size_histogram = "~{sample_id}.raw.insert_size_histogram.pdf"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1"
        disks: "local-disk " + disk_size + " HDD"
    }
}

task GroupReadByUMI {
    input {
        File input_bam
        String sample_id
        Int memory = 64
        Int disk_size = 200
    }

    command {
        java -jar /dependencies/fgbio-2.0.2.jar --compression 1 --async-io \
            GroupReadsByUmi \
            -i ~{input_bam} \
            -o ~{sample_id}.GroupedByUmi.bam \
            -f ~{sample_id}.umiHistogram.txt \
            -m 0 \
            --strategy=paired
    }

    output {
        File groupbyumi_bam = "~{sample_id}.GroupedByUmi.bam"
        File umi_histogram = "~{sample_id}.umiHistogram.txt"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1"
        disks: "local-disk " + disk_size + " HDD"
    }
}

task FgbioCollapseReadFamilies {
    input {
        File grouped_umi_bam
        String sample_id
        Int memory = 64
        Int disk_size = 200
    }

    command {
        java -jar /dependencies/fgbio-2.0.2.jar --compression 1 CallMolecularConsensusReads \
            -i ~{grouped_umi_bam} \
            -o ~{sample_id}.mol_consensus.bam \
            -p ~{sample_id} \
            --threads 2 \
            --consensus-call-overlapping-bases false \
            -M 1
    }

    output {
        File mol_consensus_bam = "~{sample_id}.mol_consensus.bam"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1"
        disks: "local-disk " + disk_size + " HDD"
    }
}

task AlignMolecularConsensusReads {
    input {
        File mol_consensus_bam
        String sample_id
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        File reference_pac
        File reference_amb
        File reference_ann
        File reference_bwt
        File reference_sa
        Int memory = 64
        Int disk_size = 200
        Int threads = 4
        Int cpu_cores = 1
    }
        String output_bam_name = "${sample_id}.mol_consensus.aligned_tmp.bam"

    command {
        samtools fastq ~{mol_consensus_bam} \
        | bwa mem -K 100000000 -t ~{threads} -p -Y ~{reference_fasta} - |  samtools view - -S -b -o ~{output_bam_name} 
    }

    output {
        File aligned_bam = "~{sample_id}.mol_consensus.aligned_tmp.bam"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        cpu: cpu_cores
        preemptible: 3
    }
}

task MergeAndSortMoleculeConsensusReads {
    input {
        File mapped_sam
        File unmapped_bam
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        String sample_id
        Int memory = 64
        Int disk_size = 200
        String sort_memory
    }

    command {
        java -jar /dependencies/fgbio-2.0.2.jar --compression 0 --async-io ZipperBams \
            -i ~{mapped_sam} \
            --unmapped ~{unmapped_bam} \
            --ref ~{reference_fasta} \
            --tags-to-reverse Consensus \
            --tags-to-revcomp Consensus \
        | samtools sort -m ~{sort_memory} - -o ~{sample_id}.mol_consensus.aligned.bam -O BAM -@ 4 && samtools index ~{sample_id}.mol_consensus.aligned.bam
    }

    output {
        File bam = "~{sample_id}.mol_consensus.aligned.bam"
        File bai = "~{sample_id}.mol_consensus.aligned.bam.bai"
    }

    runtime {
        memory: memory+ " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 3
    }
}

task CollectRawWgsMetrics {
    input {
        File ReplaceRGBam
        String sample_id
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        Int memory = 64
        Int disk_size = 200
    }


    command {
        java -jar /dependencies/picard.jar CollectWgsMetrics \
        I=~{ReplaceRGBam} O=~{sample_id}.raw.wgs_metrics.txt R=~{reference_fasta} INTERVALS=/reference_files/GRCh38_notinalldifficultregions.interval_list \
        COUNT_UNPAIRED=true MINIMUM_BASE_QUALITY=0 MINIMUM_MAPPING_QUALITY=0
    }

    output {
        File RawWgsMetrics = "~{sample_id}.raw.wgs_metrics.txt"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 3
    }
}

task CollectConsensusWgsMetrics {
    input {
        File ConsensusAlignedBam
        File ConsensusAlignedBai
        String sample_id
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        Int memory = 64
        Int disk_size = 200
    }

    command {
        java -jar /dependencies/picard.jar CollectWgsMetrics \
        I=~{ConsensusAlignedBam} O=~{sample_id}.mol_consensus.wgs_metrics.txt R=~{reference_fasta} INTERVALS=/reference_files/GRCh38_notinalldifficultregions.interval_list \
        INCLUDE_BQ_HISTOGRAM=true MINIMUM_BASE_QUALITY=30
    }

    output {
        File ConsensusWgsMetrics = "~{sample_id}.mol_consensus.wgs_metrics.txt"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 3
    }
}


task CSS_SFC_ErrorMetrics {
    input {
        File ConsensusAlignedBam
        File ConsensusAlignedBai
        String sample_id
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        File reference_pac
        File reference_amb
        File reference_ann
        File reference_bwt
        File reference_sa
        File germline_bam
        File germline_bam_index
        Int memory = 64
        Int disk_size = 200
    }

    command {
        /CODECsuite/build/codec call -b ~{ConsensusAlignedBam} \
            -L /reference_files/GRCh38_notinalldifficultregions.bed \
            -r ~{reference_fasta} \
            -m 60 \
            -q 30 \
            -d 12 \
            -n ~{germline_bam} \
            -V /reference_files/alfa_all.freq.breakmulti.hg38.af0001.vcf.gz \
            -x 6 \
            -c 4 \
            -5 \
            -g 30 \
            -G 250 \
            -Q 0.7 \
            -B 0.6 \
            -N 0.05 \
            -Y 5 \
            -W 1 \
            -a ~{sample_id}.mutant_metrics.txt \
            -e ~{sample_id}.variants_called.txt \
            -C ~{sample_id}.context_count.txt
    }

    output {
        File mutant_metrics = "~{sample_id}.mutant_metrics.txt"
        File variants_called = "~{sample_id}.variants_called.txt"
        File context_count = "~{sample_id}.context_count.txt"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 3
    }
}

task RAW_SFC_ErrorMetrics {
    input {
        File ReplaceRGBam
        File ReplaceRGBai
        String sample_id
        File reference_fasta
        File reference_fasta_index
        File reference_dict
        File reference_pac
        File reference_amb
        File reference_ann
        File reference_bwt
        File reference_sa
        File germline_bam
        File germline_bam_index
        Int memory = 32
        Int disk_size = 200
    }
    command {
        /CODECsuite/build/codec call -b ~{ReplaceRGBam} \
            -L /reference_files/GRCh38_notinalldifficultregions.bed \
            -r ~{reference_fasta} \
            -m 60 \
            -n ~{germline_bam} \
            -q 30 \
            -d 12 \
            -V /reference_files/alfa_all.freq.breakmulti.hg38.af0001.vcf.gz \
            -x 6 \
            -c 4 \
            -5 \
            -g 30 \
            -G 250 \
            -Q 0.6 \
            -B 0.6 \
            -N 0.1 \
            -Y 5 \
            -W 1 \
            -a ~{sample_id}.raw.mutant_metrics.txt \
            -e ~{sample_id}.raw.variants_called.txt \
            -C ~{sample_id}.raw.context_count.txt
    }

    output {
        File raw_mutant_metrics = "~{sample_id}.raw.mutant_metrics.txt"
        File raw_variants_called = "~{sample_id}.raw.variants_called.txt"
        File raw_context_count = "~{sample_id}.raw.context_count.txt"
    }

    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/codec:v1" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 3
    }
}

task QC_metrics {
    input {
        File byproduct_metrics
        File RawWgsMetrics
        File DuplicationMetrics
        File InsertSizeMetrics
        File ConsensusWgsMetrics
        File mutant_metrics
        Int memory = 16
        Int disk_size = 16

    }
    command <<<
        set -e
        cat ~{byproduct_metrics} | awk 'NR==2 {print $NF}' > n_total_fastq.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $9}' > n_correct.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $2}' > pct_correct.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $10}' > n_double_ligation.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $3}' > pct_double_ligation.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $12}' > n_intermol.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $5}' > pct_intermol.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $11}' > n_adp_dimer.txt
        cat ~{byproduct_metrics} | awk 'NR==2 {print $4}' > pct_adp_dimer.txt
        cat ~{RawWgsMetrics} | grep -v "#" | awk 'NR==3 {print $2}' > raw_dedupped_mean_cov.txt
        cat ~{RawWgsMetrics} | grep -v "#" | awk 'NR==3 {print $4}' > raw_dedupped_median_cov.txt
        cat ~{DuplicationMetrics} | grep -v "#" | awk 'NR==3 {print $9}' > raw_duplication_rate.txt
        cat ~{InsertSizeMetrics} | grep -v "#" | awk 'NR==3 {print $1}' > median_insert_size.txt
        cat ~{InsertSizeMetrics} | grep -v "#" | awk 'NR==3 {print $6}' > mean_insert_size.txt
        cat ~{ConsensusWgsMetrics} | grep -v "#" | awk 'NR==3 {print $2}' > mol_consensus_mean_cov.txt
        cat ~{ConsensusWgsMetrics} | grep -v "#" | awk 'NR==3 {print $4}' > mol_consensus_median_cov.txt
        cat ~{mutant_metrics} | awk 'NR==2 {print $8}' > n_snv.txt
        cat ~{mutant_metrics} | awk 'NR==2 {print $10}' > n_indel.txt
        cat ~{mutant_metrics} | awk 'NR==2 {print $3}' > n_bases_eval.txt
        cat ~{mutant_metrics} | awk 'NR==2 {print $9}' > snv_rate.txt
        cat ~{mutant_metrics} | awk 'NR==2 {print $11}' > indel_rate.txt


    >>>
    output {
      Int n_total_fastq = read_int("n_total_fastq.txt")
      Int n_correct_products = read_int("n_correct.txt")
      Float pct_correct_products = read_float("pct_correct.txt")
      Int n_double_ligation = read_int("n_double_ligation.txt")
      Float pct_double_ligation = read_float("pct_double_ligation.txt")
      Int n_intermol = read_int("n_intermol.txt")
      Float pct_intermol = read_float("pct_intermol.txt")
      Int n_adp_dimer = read_int("n_adp_dimer.txt")
      Float pct_adp_dimer = read_float("pct_adp_dimer.txt")
      Float raw_dedupped_mean_cov = read_float("raw_dedupped_mean_cov.txt")
      Int raw_dedupped_median_cov = read_int("raw_dedupped_median_cov.txt")
      Float raw_duplication_rate = read_float("raw_duplication_rate.txt")
      Float mean_insert_size = read_float("mean_insert_size.txt")
      Int median_insert_size = read_int("median_insert_size.txt")
      Float mol_consensus_mean_cov = read_float("mol_consensus_mean_cov.txt")
      Int mol_consensus_median_cov = read_int("mol_consensus_median_cov.txt")
      Int n_snv = read_int("n_snv.txt")
      Int n_indel = read_int("n_indel.txt")
      String n_bases_eval = read_string("n_bases_eval.txt")     
      Float snv_rate = read_float("snv_rate.txt")
      Float indel_rate = read_float("indel_rate.txt")
    }
    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/picard_docker" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 2
    }
}


task EvalGenomeBases {
    input {
        File eval_genome_interval
        Int memory = 16
        Int disk_size = 8
    }

    command {
        java -jar /dependencies/picard.jar IntervalListTools \
        I=~{eval_genome_interval} COUNT_OUTPUT=eval_genome_bases.txt OUTPUT_VALUE=BASES
    
    }

    output {
        String eval_genome_bases = read_string("eval_genome_bases.txt")
    }
    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/picard_docker" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 1
    }
}


task CalculateDuplexDepth {
    input {
        String eval_genome_bases
        String n_bases_eval
        Int memory = 16
        Int disk_size = 8
    }

    command <<<
    
        python3 <<CODE
        
        eval_genome_bases = "~{eval_genome_bases}"
        n_bases_eval = "~{n_bases_eval}"

        eval_genome_bases = int(eval_genome_bases)
        n_bases_eval = int(n_bases_eval)

        duplex_depth = round (n_bases_eval / eval_genome_bases, 2)
        print(duplex_depth)
        CODE
    >>>

    output {
        Float duplex_depth = read_float(stdout())
    }
    runtime {
        memory: memory + " GB"
        docker: "us.gcr.io/tag-team-160914/picard_docker" 
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 1
    }
}
