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

    call combine.gatk_combine_gvcfs as gatk_combine_gvcfs {
        input:
            cfg = cfg,
            all_vcfs = final_all_vcfs,
            all_tbis = final_all_tbis,
            output_dir = output_dir,
            batch_name = batch_name
    }

    output {
        File final_snp_gvcf = gatk_combine_gvcfs.cohort_vcf
    }
}

