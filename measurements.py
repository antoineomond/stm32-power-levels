# Must be running from the monitoring device 
import sys
import time
import board
import adafruit_ina228
import pigpio
from datetime import datetime
from statistics import StatisticsError, mean, stdev, median

EXPE_PIN = 27
expe_num = 0
done = 0
started = 0
init = 0 # Necessary when expe_pin is initially at 1 and reset to 0
s = 0
end_of_expe = False
deadline = time.time()
start_time = time.time()
timing_samples = []

if(len(sys.argv) < 8):
    print("Missing args")
    exit()
nb_expes = int(sys.argv[1])
nb_iter = int(sys.argv[2])
offset = int(sys.argv[3]) # If there was other expes done before, just offset to correctly assign the new expes
live = int(sys.argv[4])
NB_BENCHMARKS = int(sys.argv[5])
DEADLINE_ITERATION = int(sys.argv[6])
MAX_CURRENT = float(sys.argv[7])

def next_expe(user_gpio, level, tick):
    global end_of_expe
    if(end_of_expe):
        return
    
    global init
    global expe_num
    global started
    global done
    global s
    global deadline
    global start_time
    if(level == 1):
        if(init == 0):
            start_time = time.time() 
            ina228.reset_accumulators()
        init = 1
        started = 1
        deadline = time.time()
        s = tick
    if(init == 1 and level == 0):
        t = tick-s
        # tick is 32 bit timer that wraps around from 4294967295 to 0 if overflow, the following condition handles that case 
        if(tick < s):
            t += 4294967295
        timing_samples.append(t)
        started = 0
        expe_num += 1
        if(expe_num%NB_BENCHMARKS == 0):
            init = 0
        if(expe_num >= nb_expes*nb_iter):
             done = 1
        print(expe_num)

i2c = board.I2C()
ina228 = adafruit_ina228.INA228(i2c)

print("INA calibration")

# The shunt resistor is 1 Ohm
ina228.set_calibration(7.5, MAX_CURRENT)

# Configuration of the INA: trade-off longer conversion time for better accuracy
ina228.mode = adafruit_ina228.Mode.CONTINUOUS
ina228.bus_voltage_conv_time = adafruit_ina228.ConversionTime.TIME_1052_US
ina228.shunt_voltage_conv_time = adafruit_ina228.ConversionTime.TIME_1052_US
ina228.temp_conv_time = adafruit_ina228.ConversionTime.TIME_1052_US
ina228.averaging_count = adafruit_ina228.AveragingCount.COUNT_16
ina228.adc_range = 0
ina228.shunt_tempco = 25
ina228.temp_comp = 1

# Start measurements
pi = pigpio.pi()
if not pi.connected:
    print("pigpiod need to run in background")
    exit(0)
pi.callback(EXPE_PIN, pigpio.EITHER_EDGE, next_expe)
current_samples = [[] for _ in range(nb_expes*nb_iter)]
live_samples = [[] for _ in range(nb_expes*nb_iter)]
start_date = datetime.now()
print(f"Sampling starts at {start_date}")
while not done and (time.time() - deadline) < DEADLINE_ITERATION:
    if started and expe_num < nb_expes*nb_iter:  # only measure current when expe starts 
        try:
            current_val = ina228.current*1000
            current_samples[expe_num].append((current_val, ina228.power*1000, ina228.energy*1000, ina228.shunt_voltage, ina228.bus_voltage, round(time.time()-start_time, 3)))
            if live:
                live_samples[expe_num].append(current_val)
                try:
                    print(f"{current_val:.3f}, mean: {mean(live_samples[expe_num]):.3f}, std: {stdev(live_samples[expe_num]):.3f}, median: {median(live_samples[expe_num]):.3f}, max: {max(live_samples[expe_num]):.3f}, min: {min(live_samples[expe_num]):.3f}")
                # In case race condition of expe_num (empty array not accepted in statistics functions)
                except StatisticsError:
                    pass
                except ValueError:
                    pass
        # Handles race condition on expe_num
        except IndexError:
            pass
        except OSError as e:
            print(e)

    time.sleep(0.025) # 40Hz sampling

# Write results
print("Sampling ends")
result_file = "results.csv"
with open(result_file, "w") as f:
    f.write("iteration_num,conf_num,expe_num,bench_num,current_sample,power_sample,energy_sample,shunt_voltage_sample,bus_voltage_sample,current_timestamp,timing_sample\n")
    for expe_num, samples in enumerate(current_samples):
        for current_sample in samples:
            current, power, energy, shunt_voltage, bus_voltage, timestamp = current_sample
            f.write(f"{expe_num//nb_expes},{(expe_num%nb_expes)//NB_BENCHMARKS},{expe_num%nb_expes+offset},{expe_num%NB_BENCHMARKS},{current},{power},{energy},{shunt_voltage},{bus_voltage},{timestamp},\n")
    for expe_num, timing_sample in enumerate(timing_samples):
        f.write(f"{expe_num//nb_expes},{(expe_num%nb_expes)//NB_BENCHMARKS},{expe_num%nb_expes+offset},{expe_num%NB_BENCHMARKS},,,,,,,{timing_sample}\n")

print(f"Done at {datetime.now()} in {datetime.now() - start_date}s")
