set -e

# parameters
EXPE_NAME=paper
CONF_NAME=configurations.csv
NB_EXPES=32 # nb_confs * nb_benchmarks
NB_ITERS=3
NB_BENCHMARKS=4
DEADLINE_ITERATION=3600
MAX_CURRENT=0.022
OFFSET=0
ITER_OFFSET=0
PLOT_FILE=plot.r
PDF_NAME=result.pdf
GRAPH_TITLE=""

#scp -r "$FILE_TO_DEPLOY" dell_local:research/pico2-experiments/"$FILE_TO_DEPLOY"
#scp measurements.py raspberrypi:/root/dw_ina/measurements.py
#
#if [[ "$1" != "nomon" ]]; then
#	(ssh raspberrypi 'kill $(pgrep -f measurements.py)' || true)
#	ssh raspberrypi "cd /root/dw_ina && source venv/bin/activate && nohup python -u measurements.py $NB_EXPES $NB_ITERS $OFFSET $ITER_OFFSET 0 $NB_BENCHMARKS $DEADLINE_ITERATION $MAX_CURRENT > measurements.log 2>&1 < /dev/null" < /dev/null &
#	PID=$!
#fi

if [[ "$1" != "nomon" ]]; then
	# tail --pid=$PID -f /dev/null
	#
	# # retrieve results and create plot
	# mkdir -p "results/$EXPE_NAME"
	# cp "results/$CONF_NAME" "results/$EXPE_NAME/configurations.csv"
	# scp raspberrypi:/root/dw_ina/results.csv "results/$EXPE_NAME/results.csv"
	cd results && Rscript $PLOT_FILE "$EXPE_NAME/" "$GRAPH_TITLE"  && cd -

	# show graph
	echo "Showing results/$EXPE_NAME/$PDF_NAME"
	#evince "results/$EXPE_NAME/$PDF_NAME" &
fi

