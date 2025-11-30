# suffix (i.e. gclk)
SUFF :=

.PHONY: gclk, clean

compiled_verif: filelist_verif
	iverilog -c $< -o $@ -g2012
	

compiled%: filelist%
	iverilog -c $< -o $@

run%: compiled%
	vvp $<

gclk: compiled_gclk
	$(MAKE) run_gclk

clean:
	rm -f compiled compiled_*

verif: compiled_verif
	$(MAKE) run_verif