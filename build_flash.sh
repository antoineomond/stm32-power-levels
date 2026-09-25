cd /home/aomond/research/projet_sensor_loic_2025/stm32/cubeide_workspace && bear -- /opt/st/stm32cubeide_2.2.0/stm32cubeide --launcher.suppressErrors -nosplash -application org.eclipse.cdt.managedbuilder.core.headlessbuild -data . -build expes-power && cd - 

# serial
#cd /home/aomond/research/projet_sensor_loic_2025/pico/pico2-experiments/openocd && sudo src/openocd -s tcl -f interface/cmsis-dap.cfg -f target/stm32f4x.cfg -c "program $FILE_TO_DEPLOY verify reset exit 0x08000000" && cd -

# usb
STM32_Programmer_CLI -c port=usb1 -w Release/expes-power.bin 0x08000000 -v

