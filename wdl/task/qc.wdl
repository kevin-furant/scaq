import "global_config.wdl"
    alias Config as Config

File fastp = Config.fastp
File py = Config.py
File fastp_stat = Config.fastp_stat

task sample_qc {
    input {
        String sample_name
        File fq1
        File fq2
        String input_dir
        String output_dir
        String batch_name
    }

    runtime {
        cpu: 4
        backend: "Local"
    }

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
                -w ~{cpu}
    >>>

    output {
        File clean_fq1 = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}_1.clean.fq.gz"
        File clean_fq2 = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}_2.clean.fq.gz"
        File json = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}.json"
        File html = "~{output_dir}/~{batch_name}/01.qc/~{sample_name}.html"
    }
}

task qc_stat {
    inputs {
        String sample_name
        String batch_name
        String output_dir
        File json_report
    }

    runtime {
        cpu: 1
        backend: "Local"
    }

    command <<<
        #!/bin/bash
        ~{py} ~{fastp_stat} \
            --fastp-json ~{json_report} \
            --outdir ~{output_dir}/~{batch_name} \
            --samplename ~{sample_name}
    >>>

    output {
        File summary_file = ~{output_dir}/~{batch}/01.qc/~{sample_name}.summary
    }
}

workflow qc_workflow {
    input {
        File sample_info
        String input_dir
        String output_dir
        String batch_name 
    }
    #sample\tr1\tr2
    Array[Object] sample_info_objs = read_objects(sample_info)
    scatter(sample_obj in sample_info_objs){
        String sample = sample_obj.sample
        File fq1 = sample_obj.r1
        File fq2 = sample_obj.r2
        call sample_qc {
            input:
                sample_name = sample_name,
                fq1 = fq1,
                fq2 = fq2,
                input_dir = input_dir,
                output_dir = output_dir,
                batch_name = batch_name
        }

        call qc_stat {
            input:
                sample_name = sample_name,
                batch_name = batch_name,
                output_dir = output_dir,
                json_report = sample_qc.summary_file
        }
    }

    output {
        Array[File] summary_files = qc_stat.summary_file
        Array[String] samples = sample_qc.sample_name
        Array[File] all_clean_r1 = sample_qc.clean_fq1
        Array[File] all_clean_r2 = sample_qc.clean_fq2
    }
}