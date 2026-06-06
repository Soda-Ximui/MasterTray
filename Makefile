# ──────────────────────────────────────────────────────────────────────────────
# MasterTray Documentation — Makefile
# Incremental: only reconverts .md files that have changed since last build.
# Requires: GNU make, pandoc
#
# Targets:
#   make          — build all HTML (default)
#   make html     — same
#   make clean    — remove html/ and index.html
#   make rebuild  — clean + html
#   make setup    — create dirs, move *.md to docs/ (run once)
# ──────────────────────────────────────────────────────────────────────────────

DOCS    := docs
HTML    := html
CSS     := docs.css
FILTER  := fix-links.lua
MASTER  := $(DOCS)/MASTERTRAY.md

PANDOC_FLAGS := --standalone --toc --toc-depth=3 --to html5 \
                --lua-filter $(FILTER)

# All .md files in docs/ except the master (it becomes index.html)
MD_SRCS  := $(filter-out $(MASTER), $(wildcard $(DOCS)/*.md))
HTML_OUT := $(patsubst $(DOCS)/%.md, $(HTML)/%.html, $(MD_SRCS))

.PHONY: all html clean rebuild setup

all: html

html: index.html $(HTML_OUT)
	@echo Done. Open index.html to start reading.

# Master document → root index.html
index.html: $(MASTER) $(CSS) $(FILTER)
	pandoc $< $(PANDOC_FLAGS) --css $(CSS) \
	       --metadata "pagetitle=MasterTray Documentation" -o $@
	@echo "  $@"

# Individual docs → html/*.html  (incremental: only rebuilds changed files)
$(HTML)/%.html: $(DOCS)/%.md $(CSS) $(FILTER) | $(HTML)
	pandoc $< $(PANDOC_FLAGS) --css ../$(CSS) \
	       --metadata "pagetitle=$(basename $(notdir $<))" -o $@
	@echo "  $@"

$(HTML):
	mkdir -p $@

clean:
	rm -rf $(HTML) index.html

rebuild: clean html

# Run once: create docs/ and html/, move *.md into docs/ (skip HANDOFF.md)
setup:
	mkdir -p $(DOCS) $(HTML)
	@for f in *.md; do \
	    [ "$$f" = "HANDOFF.md" ] && continue; \
	    echo "  Moving $$f → $(DOCS)/"; \
	    mv "$$f" $(DOCS)/; \
	done
