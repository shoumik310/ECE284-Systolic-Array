# suffix (i.e. gclk)
SUFF :=

.PHONY: gclk, clean

compiled%: filelist%
	iverilog -c $< -o $@

run%: compiled%
	vvp $<

gclk: compiled_gclk
	$(MAKE) run_gclk

clean:
	rm -f compiled compiled_*