set -e

# parameters
EXPE_NAME=paper
CONF_NAME=configurations.csv
FILE_TO_DEPLOY='/home/aomond/research/projet_sensor_loic_2025/stm32/expes-power/Debug/expes-power.bin'
NB_EXPES=32 # nb_confs * nb_benchmarks
NB_ITERS=3
NB_BENCHMARKS=4
DEADLINE_ITERATION=3600
MAX_CURRENT=0.050
PLOT_FILE=plot.r
PDF_NAME=result.pdf
GRAPH_TITLE="Paper"

# launch experiment
#cd build/ && picotool_DIR="/home/aomond/.local/bin/picotool-2.3.0-x86_64-lin/picotool" make -j4 && cd -
#cd build/ && bear -- picotool_DIR="/home/aomond/.local/bin/picotool-2.2.0-a4-x86_64-lin/picotool" make -j4 && cd -
cd /home/aomond/research/projet_sensor_loic_2025/stm32/cubeide_workspace && bear -- /opt/st/stm32cubeide_2.2.0/stm32cubeide --launcher.suppressErrors -nosplash -application org.eclipse.cdt.managedbuilder.core.headlessbuild -data . -build expes-power && cd - 

#scp -r "$FILE_TO_DEPLOY" dell_local:research/pico2-experiments/"$FILE_TO_DEPLOY"
scp measurements.py raspberrypi:/root/dw_ina/measurements.py

if [[ "$1" != "nomon" ]]; then
	(ssh raspberrypi 'kill $(pgrep -f measurements.py)' || true)
	ssh raspberrypi "cd /root/dw_ina && source venv/bin/activate && nohup python -u measurements.py $NB_EXPES $NB_ITERS 0 0 $NB_BENCHMARKS $DEADLINE_ITERATION $MAX_CURRENT > measurements.log 2>&1 < /dev/null" < /dev/null &
	PID=$!
fi

#ssh -t dell_local "cd research/pico2-experiments/openocd && sudo src/openocd -s tcl -f interface/cmsis-dap.cfg -f target/rp2350.cfg -c 'adapter speed 5000' -c 'program ../$FILE_TO_DEPLOY verify reset exit'"
cd /home/aomond/research/projet_sensor_loic_2025/pico/pico2-experiments/openocd && sudo src/openocd -s tcl -f interface/cmsis-dap.cfg -f target/stm32f4x.cfg -c "program $FILE_TO_DEPLOY verify reset exit 0x08000000" && cd -

if [[ "$1" != "nomon" ]]; then
	tail --pid=$PID -f /dev/null
	
	# retrieve results and create plot
	mkdir -p "results/$EXPE_NAME"
	cp "results/$CONF_NAME" "results/$EXPE_NAME/configurations.csv"
	scp raspberrypi:/root/dw_ina/results.csv "results/$EXPE_NAME/results.csv"
	cd results && Rscript $PLOT_FILE "$EXPE_NAME/" "$GRAPH_TITLE"  && cd -

	# show graph
	echo "Showing results/$EXPE_NAME/$PDF_NAME"
	evince "results/$EXPE_NAME/$PDF_NAME" &
fi

