version 1.1

import "global_config.wdl"

task sample_qc {
    input {
        Config cfg
        String sample_name
        File fq1
        File fq2
        String output_dir
        String batch_name
    }

    runtime {
        cpu: 4
    }
    
    File fastp = cfg.fastp

    command <<<
        #!/bin/bash
        mkdir -p ~{output_dir}/~{batch_name}/01.qc
        clean_fq1=~{output_dir}/~{batch_name}/01.qc/~{sample_name}_1.clean.fq.gz
        clean_fq2=~{output_dir}/~{batch_name}/01.qc/~{sample_name}_2.clean.fq.gz
        json_report=~{output_dir}/~{batch_name}/01.qc/~{sample_name}.json
        html_report=~{output_dir}/~{batch_name}/01.qc/~{sample_name}.html
        ~{fastp} -i ~{fq1} -o ${clean_fq1} \
                -I ~{fq2} -O ${clean_fq2} \
                -j ${json_report} -h ${html_report} \
                -w 4
    >>>

    output {
        File clean_fq1 = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}_1.clean.fq.gz"
        File clean_fq2 = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}_2.clean.fq.gz"
        File json = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}.json"
        File html = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}.html"
        String sample = sample_name
    }
}

task qc_stat {
    input {
        Config cfg
        String sample_name
        String batch_name
        String output_dir
        File json_report
    }

    File py = cfg.py
    File fastp_stat = cfg.fastp_stat

    runtime {
        cpu: 1
    }

    command <<<
        #!/bin/bash
        ~{py} ~{fastp_stat} \
            --fastp-json ~{json_report} \
            --outdir ~{output_dir}/~{batch_name}/01.qc \
            --samplename ~{sample_name}
    >>>

    output {
        File summary_file = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}.summary"
    }
}

workflow qc_workflow {
    input {
        Config cfg
        File sample_info
        String output_dir
        String batch_name 
    }
    #read_objects cromwell未实现，用read_json 代替
    Map[String, Array[File]] sample_info_map = read_json(sample_info)
    Array[String] samples = keys(sample_info_map)
    scatter(sample in samples){
        File fq1 = sample_info_map[sample][0]
        File fq2 = sample_info_map[sample][1]
        call sample_qc {
            input:
                cfg = cfg,
                sample_name = sample,
                fq1 = fq1,
                fq2 = fq2,
                output_dir = output_dir,
                batch_name = batch_name
        }

        call qc_stat {
            input:
                cfg = cfg,
                sample_name = sample,
                batch_name = batch_name,
                output_dir = output_dir,
                json_report = sample_qc.json
        }
    }

    output {
        Array[File] summary_files = qc_stat.summary_file
        Array[String] sample_names = sample_qc.sample
        Array[File] all_clean_r1 = sample_qc.clean_fq1
        Array[File] all_clean_r2 = sample_qc.clean_fq2
    }
}