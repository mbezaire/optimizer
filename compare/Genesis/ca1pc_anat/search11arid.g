// genesis

//
// search.g: functions for simulated annealing parameter searches
//

// This function prints the current parameter values.
// It's useful for debugging.

function print_params
    int i

    echo
    for (i = 0; i < NPARAMS; i = i + 1)
        echo Param {i} value: {getfield /par current[{i}]}
    end
    echo
end


// This function regenerates the original Vm output file and
// spike time file.

function make_orig
    silent 2

    newsim {origcellfile} 0
    run_transfer
    mv {sim_output_file} {real_vmax_file}
    silent 0
end


// This function runs one iteration of the parameter search
// and calculates a match value.

function one_run(adjust_flag)
    int adjust_flag   // if 1, then adjust parameters

    float match

    silent 2
    // Create a new cell and set its parameters.
    newsim {cellfile} {adjust_flag}

    // Simulate the cell with several different input currents.
    run_transfer

    match = 0.0

    gen2spk {sim_output_file} {DEL1} {WIDTH} {tmax}
    match = {match} + 10 * {spkcmp {real_spk_file} {sim_spk_file} \
        -pow1 0.1 -pow2 0.6 -msp 0.2 -nmp 0.0}

    match = {match} + 1e-4 * {diff_comp}    // trace matching

    silent 0
    return {match}
end


// This function actually runs the parameter search:

function do_search
    int   done   = 0
    float best, match
    int   iterations_per_round = 100
    int compt,i,time

    // max_iterations = the maximum number of iterations before saving and
    // restarting, *not* necessarily the maximum number of iterations in
    // the parameter search as a whole.

    int   max_iterations = 1000
    int   sim_num        = 0    // Simulations this round.

    make_vmtable

    if (!restore)
        // Initialize match file.  This holds a list of match
        // values obtained at various points in the search.
        openfile  {matchfile} w
        writefile {matchfile} "% iteration best_match"
        closefile {matchfile}
    end

    // Load parameter table with randomly selected values in range
    // or restore old parameter table.

    if (restore)
        echo
        echo Restoring parameter search object...
        echo

        call /par RESTORE {restore_file}
        best = {getfield /par best_match}
    else
        call /par INITSEARCH random // start at random
        match = {one_run 1}
        best = match

        echo  iteration: {sim_num} match = {match} \
          temperature = {getfield /par temperature} \
          best match = {getfield /par best_match}
        echo

        call /par EVALUATE {match}

        echo
        call /par DISPLAY2
        echo

        call /par SAVEBEST {best_param_file}

        sh cp {sim_spk_file} {sim_spk_file_best}

		setfield /voltage_c table =+=/vdata_c/table
		openfile data/voltage_c.best w
		for(time=0; time < 5000; time=time+1)
		    writefile data/voltage_c.best {getfield /voltage_c table->table[{time}]}
		end
		closefile data/voltage_c.best

        call /par UPDATE_PARAMS
        sim_num = sim_num + 1
    end

    while (!done && (sim_num < max_iterations))
        match = {one_run 1}

        echo  Simulation: {getfield /par iteration_number} match = {match} \
          temperature = {getfield /par temperature} \
          best match = {getfield /par best_match}
        echo

        call /par EVALUATE {match}

        if (match < best)
            best = match
            echo
            echo >>>>>>>>>>>>> New best match achieved!
            echo
            call /par DISPLAY
            echo

            call /par SAVEBEST {best_param_file}

            sh cp {sim_spk_file} {sim_spk_file_best}

		setfield /voltage_c table =+=/vdata_c/table
		openfile data/voltage_c.best w
		for(time=0; time < 5000; time=time+1)
		    writefile data/voltage_c.best {getfield /voltage_c table->table[{time}]}
		end
		closefile data/voltage_c.best

        end

        call /par UPDATE_PARAMS
        sim_num = sim_num + 1

        done = {getfield /par done}

        if ({sim_num % iterations_per_round} == 0)
            openfile  {matchfile} a
            writefile {matchfile} {getfield /par iteration_number} {best}
            closefile {matchfile}
        end
    end

    if (done)
        echo
        echo DONE! Best match is: {getfield /par best_match}
        echo

        // Save results to match file; this is important
        // since not all simulations last long enough
        // to have the match values recorded above.

        openfile  {matchfile} a
        writefile {matchfile} {getfield /par iteration_number} {best}
        closefile {matchfile}

        openfile sim_status w
        writefile sim_status 2
        closefile sim_status

        sh rm {sim_output_file}
        sh rm {sim_spk_file}
    else
        echo
        echo Saving paramtable object...
        echo

        call /par SAVE {restore_file}
        openfile sim_status w
        writefile sim_status 1
        closefile sim_status
    end
end


