# Everything here is SQL. This file only decides the order and fails the build.
DUCKDB      ?= .bin/duckdb
DUCKDB_VER  ?= 1.5.5
DB          ?= build/funnels.duckdb
MODELS      := $(sort $(wildcard sql/*.sql))
CHECKS      := $(sort $(wildcard tests/assert_*.sql))

.PHONY: help duckdb build check check-all report clean

help:
	@echo "make duckdb    - fetch the DuckDB CLI into .bin (once)"
	@echo "make build     - run every model in sql/ in order, into $(DB)"
	@echo "make check     - build, then run every assertion in tests/"
	@echo "make report    - build, then print the published tables"
	@echo "make clean     - remove the database"

$(DUCKDB):
	@mkdir -p .bin
	curl -fsSL -o .bin/duckdb.zip \
	  "https://github.com/duckdb/duckdb/releases/download/v$(DUCKDB_VER)/duckdb_cli-linux-amd64.zip"
	cd .bin && unzip -o -q duckdb.zip && rm duckdb.zip
	@chmod +x $(DUCKDB)

duckdb: $(DUCKDB)

build: $(DUCKDB)
	@mkdir -p build
	@rm -f $(DB) $(DB).wal
	@for model in $(MODELS); do \
	  printf '  model %s\n' "$$model"; \
	  $(DUCKDB) $(DB) -c ".read $$model" > /dev/null || exit 1; \
	done
	@echo "built $(DB)"

# An assertion is a query that returns the rows that BREAK it. Zero rows is a pass, which is why the
# harness needs no assertion library and no second language.
#
# The exit status is checked as well as the output, and that is not belt and braces: the first version
# of this target only looked at the output, so an assertion that failed to PARSE printed nothing to
# stdout and was reported as a pass. A harness that cannot tell "the claim holds" from "the query never
# ran" is a harness that reports green for a file it never executed.
check: build
	@failed=0; \
	for assertion in $(CHECKS); do \
	  out=$$($(DUCKDB) $(DB) -noheader -list -c ".read $$assertion" 2>&1); \
	  status=$$?; \
	  if [ $$status -ne 0 ]; then \
	    printf 'ERROR %s did not run\n%s\n' "$$assertion" "$$out"; failed=1; \
	  elif [ -n "$$out" ]; then \
	    printf 'FAIL  %s\n%s\n' "$$assertion" "$$out"; failed=1; \
	  else \
	    printf 'ok    %s\n' "$$assertion"; \
	  fi; \
	done; \
	[ $$failed -eq 0 ] || { echo "assertions failed"; exit 1; }
	@echo "all assertions passed"

check-all: check report

report: build
	@for query in docs/report_*.sql; do \
	  printf '\n=== %s\n' "$$query"; \
	  $(DUCKDB) $(DB) -box -c ".read $$query"; \
	done

clean:
	rm -rf build
