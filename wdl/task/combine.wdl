version 1.1

task GLnexus {
    input {
        File input_file
        String input_string = "default_value"
        Int input_int = 1
        Float input_float = 0.0
    }

    runtime {
        backend: "Local"
        container: "glnexus_v1.4.1.sif"
    }

    command <<<
        #!/bin/bash
        glnexus_cli --dir /tempdir/GLnexus.DB \
            --config gatk \
            --threads 80 \
            --list 
    >>>

    output {
        File image.sif = "output_GLnexus.txt"
        String output_string = "finished"
    }
}

