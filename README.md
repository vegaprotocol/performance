# performance
Tools to allow automatic performance testing of the core system

# HOWTO
There are 2 main scripts in this repo alone with a csv file used to define the tests that are to be executed.

## prerequisites.sh
This scripts checks that the systme has the tools it needs to run such as `git`, `golang` and `curl`. It will check each one of the required trools is available and prompt the user for any that are missing. Once all the tools are there, the code for the Vega parts will be pulled down and built with the latest version available.

## runtests.sh
This scripts starts up the Vega system and executes each test one by one, collecting the CPU usage of the core and datanode along with event rates and backlog sizes during the run. Each test generates an result file with the collected data inside it.

## input.csv
The parameters for each test are stored in here. The first line must be left alone and shows the columns of data needed by the scripts. The test name must be unique or the output results will overwrite previous runs.
