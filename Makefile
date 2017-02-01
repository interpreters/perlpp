# Hacky makefile for perlpp
# Chris White, 2017.
all: test

test:
	perl -e 'use Test::Harness "runtests"; runtests @ARGV;' -- t/*.t 2>/dev/null


#Note: if you don't have Test::Harness, you can use:
#	for f in t/*.t ; do echo "$$f" ; perl "$$f" ; done 2>/dev/null

