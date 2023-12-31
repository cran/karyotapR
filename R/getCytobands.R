#' Add chromosome cytobands and chromosome arms to `TapestriExperiment`
#'
#' `getCytobands()` retrieves the chromosome arm and cytoband for each probe based on stored positional data and saves them in `rowData`.
#' This is run automatically as part of [createTapestriExperiment()].
#' Note: Some downstream smoothing and plotting functions may fail if chromosome arms are not present in `rowData`.
#'
#' @param TapestriExperiment `TapestriExperiment` object.
#' @param genome Character, reference genome to use. Only hg19 is currently supported.
#' @param verbose Logical, if `TRUE` (default), progress is output as message text.
#'
#' @return `TapestriExperiment` object with `rowData` updated to include chromosome arms and cytobands.
#' @export
#'
#' @concept build experiment
#'
#' @examples
#' tap.object <- newTapestriExperimentExample() # example TapestriExperiment object
#' tap.object <- getCytobands(tap.object, genome = "hg19")
getCytobands <- function(TapestriExperiment, genome = "hg19", verbose = TRUE) {
  genome <- tolower(genome)

  if (genome != "hg19") {
    cli::cli_abort("{.var genome} {.q {genome}} not found. Only {.q hg19} is currently supported.")
  }

  if (verbose) {
    if (genome == "hg19") {
      cli::cli_alert_info("Adding cytobands from hg19.")
    }
  }
  # only add chr label for arms to chrs 1-22, X, Y
  chr.vector <- as.character(SingleCellExperiment::rowData(TapestriExperiment)$chr)
  chr.vector <- ifelse(chr.vector %in% c(1:22, "X", "Y"),
    paste0("chr", chr.vector),
    chr.vector
  )

  amplicon.df <- data.frame(
    seqnames = chr.vector,
    start = SingleCellExperiment::rowData(TapestriExperiment)$start.pos,
    end = SingleCellExperiment::rowData(TapestriExperiment)$end.pos,
    id = SingleCellExperiment::rowData(TapestriExperiment)$probe.id
  )

  cytoband.data <- .GetCytobands.df(amplicon.df, return.genomic.ranges = TRUE)
  cytoband.data <- as.data.frame(cytoband.data)
  rownames(cytoband.data) <- cytoband.data$probe.id # overwrite to prevent loss

  existing.amplicon.data <- as.data.frame(SingleCellExperiment::rowData(TapestriExperiment)) # get existing row data

  # reorder cytoband data
  cytoband.data <- cytoband.data[rownames(existing.amplicon.data), ]

  # remove chr prefix from arms
  arm.labels <- strsplit(as.character(cytoband.data$arm), split = "chr", fixed = TRUE)
  arm.labels <- unlist(lapply(arm.labels, function(x) x[length(x)]))
  arm.labels <- unlist(arm.labels)
  cytoband.data$arm <- factor(arm.labels, levels = unique(arm.labels))

  # add to row data
  SummarizedExperiment::rowData(TapestriExperiment)$cytoband <- cytoband.data$cytoband
  SummarizedExperiment::rowData(TapestriExperiment)$arm <- cytoband.data$arm

  return(TapestriExperiment)
}

.GetCytobands.df <- function(input.df, return.genomic.ranges = FALSE) {
  amplicon.gr <- GenomicRanges::GRanges(
    seqnames = S4Vectors::Rle(input.df$seqnames),
    ranges = IRanges::IRanges(
      start = input.df$start,
      end = input.df$end,
      names = input.df$id
    ),
    strand = S4Vectors::Rle(
      values = GenomicRanges::strand("*"),
      lengths = nrow(input.df)
    )
  )

  overlap.hits <- GenomicRanges::findOverlaps(
    amplicon.gr,
    cytoband.hg19.genomicRanges
  )

  cytoband.matches <- character(length = S4Vectors::queryLength(overlap.hits))
  cytoband.matches[] <- NA
  cytoband.matches[S4Vectors::queryHits(overlap.hits)] <- S4Vectors::mcols(cytoband.hg19.genomicRanges)[, "cytoband"][S4Vectors::subjectHits(overlap.hits)]

  S4Vectors::mcols(amplicon.gr)$cytoband <- cytoband.matches

  chromosome.arms <- ifelse(is.na(amplicon.gr$cytoband),
    amplicon.gr$cytoband,
    paste0(S4Vectors::decode(GenomicRanges::seqnames(amplicon.gr)), substr(amplicon.gr$cytoband, 1, 1))
  )

  S4Vectors::mcols(amplicon.gr)$arm <- chromosome.arms
  S4Vectors::mcols(amplicon.gr)$arm <- factor(
    chromosome.arms,
    unique(chromosome.arms)
  )
  S4Vectors::mcols(amplicon.gr)$probe.id <- names(amplicon.gr)

  if (return.genomic.ranges) {
    return(amplicon.gr)
  } else {
    return(as.data.frame(amplicon.gr))
  }
}
