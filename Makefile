# Hacky makefile for perlpp
# Chris White, 2017.
.PHONY: all test hand_test

all: perlpp.pl test

perlpp.pl: perlpp.src.pl Makefile
	# Pack using App::FatPacker
	fatpack pack $< > $@
	# Cut the Getopt::Long perlpod to save space.
	sed -En -i \
		'1,/^[[:space:]]+#{5,}[[:space:]]+Documentation/p;/^GETOPT_LONG/,$$p' \
		$@
	sed -Ei 's/[[:space:]]+$$//g' $@	# no trailing whitespace
	sed -Ei '1,/^=pod/{/^$$/d}' $@		# no blank lines outside the pod

test:
	perl -e 'use Test::Harness "runtests"; runtests @ARGV;' -- t/*.t 2>/dev/null


# Test if you don't have Test::Harness
hand_test:
	for f in t/*.t ; do echo "$$f" ; perl "$$f" ; done

