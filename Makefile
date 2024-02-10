export DC_HOME=/tools/eda/synopsys/syn/U-2022.12-SP3
all: com sim

com:
	vcs \
	+define+DEBUG \
	+define+DUMP \
	+define+FSDB_ON \
	+define+FAST_COMPILE \
	-f file_tb.f \
	-l com.log \
	-full64 \
    -debug_acc+all +v2k \
	+nospecify \
	+notimingchecks \
    -sverilog \
    -timescale=1ps/1ps


sim:
	./simv \
    -l sim.log  \
    -fsdb \
    +nospecify +notimingchecks +fsdb+autoflush +vcs+dumparrays

v:
	Verdi -nologo -f file_tb.f -ssf testbench.fsdb &

v-sx:
	Verdi-SX -nologo -f file.f -ssf testbench.fsdb &

clear:
	rm -rf simv* csrc

clean:
	rm -rf  simv* *.fsdb* *.vpd DVEfiles csrc simv* ucli* *.log novas* *Verdi* vpd2fsdb* ./peline_out/*.txt

c:
	rm -rf  simv* *.fsdb* *.vpd DVEfiles csrc simv* ucli* *.log novas* *Verdi* vpd2fsdb* ./peline_out/*.txt *txt result/*txt verdiLog*

