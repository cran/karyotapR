#' Move non-genome probes counts and metadata to altExp slots
#'
#' `moveNonGenomeProbes()` takes the probe IDs corresponding to `grnaProbe` and `barcodeProbe` slots of the `TapestriExperiment` object,
#' as well as probes on chrY, and moves them to their own `altExp` slots in the object.
#' This allows those counts and associated metadata to be manipulated separately without interfering with the probes used for CNV measurements which target the endogenous genome.
#' [SingleCellExperiment::splitAltExps()] can be used for manual specification of probes to move to `altExp` slots if the shortcut slots are not used.
#'
#' `moveNonGenomeProbes()` moves probes corresponding to the specified tags to `altExp` (alternative experiment) slots in the `TapestriExperiment` object.
#' These probes should be those which do not correspond to a chromosome and therefore would not be used to call copy number variants.
#' The exception is probes on chromosome Y; CNVs of chrY are more rare, so we move it to an `altExp` for separate analysis.
#' Probes corresponding to the `barcodeProbe` and `grnaProbe` slots, which are specified by the `panel.id` shortcut or manually (see [Custom Slot Getters and Setters]),
#' are automatically moved to `altExp` by this operation as well.
#' If such probes are not present, the function will only generate a warning message, so it is always safe (and recommended) to run by default.
#' Any remaining probes that are not targeting a human chromosome and are not specified by the shortcut tags are moved to the `otherProbeCounts` slot.
#' This function is run automatically by default and with default behavior as part of [createTapestriExperiment()].
#'
#' @param TapestriExperiment `TapestriExperiment` object.
#'
#' @return `TapestriExperiment` with `altExp` slots filled with counts and metadata for non-genomic probes.
#' @export
#'
#' @seealso [SingleCellExperiment::splitAltExps()] for manual specification of probes to move to `altExp` slots.
#'
#' @concept build experiment
#'
#' @examples
#' tap.object <- newTapestriExperimentExample() # example TapestriExperiment
#' tap.object <- moveNonGenomeProbes(tap.object)
moveNonGenomeProbes <- function(TapestriExperiment) {
  feature.type <- rep("otherProbeCounts", nrow(TapestriExperiment))

  feature.type[which(rowData(TapestriExperiment)$chr %in% c(1:22, "X"))] <- "CNV"

  barcodeProbe <- TapestriExperiment@barcodeProbe
  grnaProbe <- TapestriExperiment@grnaProbe

  if (grnaProbe != "not specified") {
    probe.index <- which(rownames(TapestriExperiment) == grnaProbe)
    feature.type[probe.index] <- "grnaCounts"
    cli::cli_alert_info("Moving gRNA probe {rownames(TapestriExperiment)[probe.index]} to {.var altExp} slot {.q grnaCounts}.")
  }

  if (barcodeProbe != "not specified") {
    probe.index <- which(rownames(TapestriExperiment) == barcodeProbe)
    feature.type[probe.index] <- "barcodeCounts"
    cli::cli_alert_info("Moving barcode probe {rownames(TapestriExperiment)[probe.index]} to {.var altExp} slot {.q barcodeCounts}.")
  }

  probe.index <- which(rowData(TapestriExperiment)$chr == "Y")
  if (S4Vectors::isEmpty(probe.index)) {
    cli::cli_alert_info("ChrY probe ID(s) not found in TapestriExperiment object.")
  } else {
    feature.type[probe.index] <- "chrYCounts"
    cli::cli_alert_info("Moving chrY probe(s) {rownames(TapestriExperiment)[probe.index]} to {.var altExp} slot {.q chrYCounts}.")
  }

  probe.index <- which(feature.type == "otherProbeCounts")
  if (any(feature.type == "otherProbeCounts")) {
    cli::cli_alert_info("Moving other non-genomic probe(s) {rownames(TapestriExperiment)[probe.index]} to {.var altExp} slot {.q otherProbeCounts}.")
  }

  if (all(feature.type == "CNV")) {
    cli::cli_alert_info("No non-genomic probe IDs found.")
    return(TapestriExperiment)
  }

  TapestriExperiment <- SingleCellExperiment::splitAltExps(TapestriExperiment,
    feature.type,
    ref = "CNV"
  )

  return(TapestriExperiment)
}
