
.PHONY: gclk clean verif run run% vanilla part2

# compiled_verif: filelist_verif
# 	iverilog -c $< -o $@ -g2012

compiled: filelist
	iverilog -c $< -o $@

run: compiled
	vvp $<
	
compiled%: filelist%
	iverilog -c $< -o $@ -g2012

run%: compiled%
	vvp $<

vanilla: compiled_vanilla
	$(MAKE) run_vanilla

gclk: compiled_gclk
	$(MAKE) run_gclk

verif: compiled_verif
	$(MAKE) run_verif

part2: compiled_part2
	$(MAKE) run_part2

clean:
	rm -f compiled compiled_*
