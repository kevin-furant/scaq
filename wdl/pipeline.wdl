version 1.1

import "task/qc.wdl"
import "task/aligner.wdl"
import "task/hc.wdl"
import "task/combine.wdl"
import "task/global_config.wdl"
#主workflow， subworkflow将会通过主workflow调用
#您只能从某一个节点作为启始点，比如您选择is_qc=true, 那is_align, is_hc就得是false
workflow QCpipeline {
    input {
            Config cfg
            String output_dir
            String batch_name
            Boolean is_qc
            Boolean is_align
            Boolean is_hc
            File? qc_sample_info
            File? align_sample_info
            File? hc_sample_info
            Array[Array[Int]] gpu_ids
    }

    if (is_qc) {
        File sample_info = select_first([qc_sample_info])
        call qc.qc_workflow as qc_workflow {
            input:
                cfg = cfg,
                sample_info = sample_info,
                output_dir = output_dir,
                batch_name = batch_name
        }

        call aligner.aligner_workflow as flow_aligner_workflow {
            input:
                cfg = cfg,
                batch_name = batch_name,
                output_dir = output_dir,
                samples = qc_workflow.sample_names,
                all_clean_r1 = qc_workflow.all_clean_r1,
                all_clean_r2 = qc_workflow.all_clean_r2,
                gpu_ids = gpu_ids
        }

        call hc.hc_workflow as flow_hc_workflow {
            input:
                cfg = cfg,
                output_dir = output_dir,
                batch_name = batch_name,
                input_samples = flow_aligner_workflow.sample_names,
                all_bams = flow_aligner_workflow.all_bams,
                all_bais = flow_aligner_workflow.all_bais,
                gpu_ids = gpu_ids
        }
    }

    if (is_align) {
        call aligner.aligner_workflow as start_aligner_workflow {
            input:
                cfg = cfg,
                sample_info = align_sample_info,
                batch_name = batch_name,
                output_dir = output_dir,
                gpu_ids = gpu_ids
        }

        call hc.hc_workflow as flow_hc_workflow_2 {
            input:
                cfg = cfg,
                output_dir = output_dir,
                batch_name = batch_name,
                input_samples = start_aligner_workflow.sample_names,
                all_bams = start_aligner_workflow.all_bams,
                all_bais = start_aligner_workflow.all_bais,
                gpu_ids = gpu_ids
        }
    }

    if (is_qc) {
        Array[File] all_bams_qc = select_first([flow_aligner_workflow.all_bams])
        Array[File] all_bais_qc = select_first([flow_aligner_workflow.all_bais])
        Array[Pair[File, File]] all_bam_bai_pairs_qc = zip(all_bams_qc, all_bais_qc)
        scatter(bam_bai_pair in all_bam_bai_pairs_qc) {
            File qc_bam = bam_bai_pair.left
            File qc_bai = bam_bai_pair.right
            String qc_sample_name = basename(qc_bam, ".bam")
            call aligner.bam_stat as qc_bam_stat {
                input:
                    cfg = cfg,
                    input_bam = qc_bam,
                    input_bai = qc_bai,
                    sample_name = qc_sample_name,
                    batch_name = batch_name,
                    output_dir = output_dir
            }
         }
         call aligner.stat_plot as qc_stat_plot {
            input:
                cfg = cfg,
                input_bam_stats = qc_bam_stat.bam_stat,
                output_dir = output_dir,
                batch_name = batch_name
         }
    }

    if (is_align) {
        Array[File] all_bams_align = select_first([start_aligner_workflow.all_bams])
        Array[File] all_bais_align = select_first([start_aligner_workflow.all_bais])
        Array[Pair[File, File]] all_bam_bai_pairs_align = zip(all_bams_align, all_bais_align)
        scatter(bam_bai_pair in all_bam_bai_pairs_align) {
            File align_bam = bam_bai_pair.left
            File align_bai = bam_bai_pair.right
            String align_sample_name = basename(align_bam, ".bam")
            call aligner.bam_stat as align_bam_stat {
                input:
                    cfg = cfg,
                    input_bam = align_bam,
                    input_bai = align_bai,
                    sample_name = align_sample_name,
                    batch_name = batch_name,
                    output_dir = output_dir
            }
         }
        call aligner.stat_plot as align_stat_plot {
            input:
                cfg = cfg,
                input_bam_stats = align_bam_stat.bam_stat,
                output_dir = output_dir,
                batch_name = batch_name
        }
    }

    if (is_hc) {
        call hc.hc_workflow as start_hc_workflow {
            input:
                cfg = cfg,
                sample_info = hc_sample_info,
                output_dir = output_dir,
                batch_name = batch_name,
                gpu_ids = gpu_ids
        }
    }

    Array[File] final_all_vcfs = select_first([flow_hc_workflow.all_vcfs, flow_hc_workflow_2.all_vcfs, start_hc_workflow.all_vcfs])
    Array[File] final_all_tbis = select_first([flow_hc_workflow.all_tbis, flow_hc_workflow_2.all_tbis, start_hc_workflow.all_tbis])
    call combine.GLnexus as GLnexus {
        input:
            all_vcfs = final_all_vcfs,
            all_tbis = final_all_tbis,
            output_dir = output_dir,
            batch_name = batch_name
    }

    call combine.combine_gvcfs as combine_gvcfs {
        input:
            cfg = cfg,
            input_bcf_file = GLnexus.gvcf_bcf_file,
            output_dir = output_dir,
            batch_name = batch_name
    }

    output {
        File final_snp_gvcf = combine_gvcfs.combine_gvcf_snp
        File final_indel_gvcf = combine_gvcfs.combine_gvcf_indel
        File final_snp_stat = combine_gvcfs.gvcf_stat_snp
        File final_indel_stat = combine_gvcfs.gvcf_stat_indel
        Array[File] all_bam_stats = flatten(select_all([qc_bam_stat.bam_stat, align_bam_stat.bam_stat]))
    }
}