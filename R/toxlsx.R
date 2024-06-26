#' @name toxlsx
#'
#' @title Convert R data frames to excel files
#'
#' @description This function allows you to write R data frames given
#' in the `object` argument to excel files located in the `path` directory.
#' The function takes several arguments but the only two required are `object` and `path`. \cr
#' See examples gallery : <https://ddotta.github.io/tablexlsx/articles/aa-examples.html>
#'
#' @param object data.frame to be converted to excel
#' @param tosheet list of sheet names for each element of object.
#'   If omitted, sheets are named by default "Sheet 1", "Sheet 2"...
#' @param title list of title for each element of object
#'   If omitted, title takes the name of the dataframe in `object`
#' @param columnstyle list of style for columns of each element of object
#'   Only useful if you want to customise the style of each column `
#' @param footnote1 list of footnote1 for each element of object
#'   If omitted, no footnote1
#' @param footnote2 list of footnote2 for each element of object
#'   If omitted, no footnote2
#' @param footnote3 list of footnote3 for each element of object
#'   If omitted, no footnote3
#' @param mergecol list of character vectors that indicate the columns for which we want to merge the modalities
#' @param bygroup list of character vectors indicating the names of the columns by which to group
#' @param groupname list of booleans indicating whether the names of the grouping variables should be written
#' @param path path to save excel file
#' @param filename name for the excel file ("Export" by default)
#' @param asTable logical indicating if data should be written as an Excel Table (FALSE by default)
#' @param automaticopen logical indicating if excel file should open automatically (FALSE by default)
#'
#' @examples
#' # Simply export a data frame to an xlsx file
#' # For more examples, see examples gallery :
#' # https://ddotta.github.io/tablexlsx/articles/aa-examples.html
#' \dontrun{
#' toxlsx(object = iris, path = tempdir())
#' }
#'
#' @return an excel file
#' @export
#'
toxlsx <- function(object,
                   tosheet = list(),
                   title = list(),
                   columnstyle = list("default" = NULL),
                   footnote1 = list(),
                   footnote2 = list(),
                   footnote3 = list(),
                   mergecol = NULL,
                   bygroup = list(),
                   groupname = FALSE,
                   path,
                   filename = "Export",
                   asTable = FALSE,
                   automaticopen = FALSE) {

  if (isTRUE(asTable) & !is.null(mergecol)) {
    stop("mergecol cannot be defined when asTable is TRUE")
  }

  # check if object is a data frame or a list
  assert_class(object, c("data.frame", "list"))
  # check if object is grouped or not
  assert_grouped(object)

  # Code to make the function works with both %>% and |> operators
  parents <- lapply(sys.frames(), parent.env)
  is_magrittr_env <- vapply(parents, identical, logical(1), y = environment(`%>%`))
  magrittr_pipe <- any(is_magrittr_env)
  is_list <- inherits(object, "list")

  # Before conversion to string, we store object in get_object
  get_object <- object

  if (magrittr_pipe) {
    object <- get("lhs", sys.frames()[[max(which(is_magrittr_env))]])
  } else {
    object <- substitute(object)
  }

  # output_name is a string vector containing the name of all data frames passed in the object argument
  if (is_list) {
    if (magrittr_pipe) {
      object <- parse(text = object)
    }
    output_name <- unlist(lapply(substitute(object), deparse)[-1])
  } else {
    output_name <- deparse(object)
  }

  tosheet <- if_atomic_to_list(tosheet, output_name)
  title <- if_atomic_to_list(title, output_name)
  footnote1 <- if_atomic_to_list(footnote1, output_name)
  footnote2 <- if_atomic_to_list(footnote2, output_name)
  footnote3 <- if_atomic_to_list(footnote3, output_name)
  mergecol <- if_atomic_to_list(mergecol, output_name)
  bygroup <- if_atomic_to_list(bygroup, output_name)
  groupname <- if_atomic_to_list(groupname, output_name)

  # check if tosheet is a list
  assert_class(tosheet, "list")
  # check if title is a list
  assert_class(title, "list")
  # check if columnstyle is a list
  assert_class(columnstyle, "list")
  # check if columnstyle is a named list
  assert_named_list(columnstyle)
  # check if footnote1 is a list
  assert_class(footnote1, "list")
  # check if footnote2 is a list
  assert_class(footnote2, "list")
  # check if footnote3 is a list
  assert_class(footnote3, "list")


  # Initialize an empty list for output
  # and name the elements of the output list with output_name
  output <- setNames(
    vector("list", length = length(output_name)),
    output_name
  )

  # Initialize also an empty list for Sheetslist
  Sheetslist <- output

  # Loop through each element in output_name
  for (df in output_name) {
    output[[df]][["sheet"]] <-
      if (length(tosheet) == 0) {
        # If tosheet is not provided, use "Sheet #" as the sheet name
        paste0("Sheet ", as.character(which(output_name == df)))
      } else {
        # Else use df as the sheet name
        tosheet[[df]]
      }
    Sheetslist[which(output_name == df)] <- output[[df]][["sheet"]]
    output[[df]][["title"]] <- if (length(title) == 0) df else title[[df]]
    output[[df]][["column"]] <- if (paste(names(columnstyle), collapse = "") %in% "default") list() else columnstyle[[df]]
    output[[df]][["footnote1"]] <- if (length(footnote1) == 0) "" else footnote1[[df]]
    output[[df]][["footnote2"]] <- if (length(footnote2) == 0) "" else footnote2[[df]]
    output[[df]][["footnote3"]] <- if (length(footnote3) == 0) "" else footnote3[[df]]
    output[[df]][["mergecol"]] <- if (length(mergecol) == 0) character(0) else mergecol[[df]]
    output[[df]][["bygroup"]] <- if (length(bygroup) == 0) character(0) else bygroup[[df]]
    output[[df]][["groupname"]] <- if (length(groupname) == 0) logical(0) else groupname[[df]]
  }

  # Creation empty workbook
  wb <- openxlsx::createWorkbook()

  ### Fill workbook

  # loop for each df in output_name
  for (df in output_name) {

    # If argument columnstyle is not filled in the function
    if (paste(names(columnstyle), collapse = "") %in% "default") {
      # Initialize empty named list to format columns (ColumnList)
      ColumnList <- as.list(setNames(
        rep("character", length(names(get(df)))),
        paste0("c", seq_along(names(get(df))))
      ))

      # Fill ColumnList
      for (i in seq_along(ColumnList)) {
        ColumnList[[i]] <- style[[ColumnList[[paste0("c", i)]]]]
      }

    # Else if argument columnstyle is filled in the function
    } else {
      # Initialize empty named list to format columns (ColumnList)
      ColumnList <- setNames(
        vector("list", length = length(output[[df]][["column"]])),
        names(output[[df]][["column"]])
      )

      # Fill ColumnList
      for (i in seq_along(output[[df]][["column"]])) {
        ColumnList[[i]] <- style[[output[[df]][["column"]][[paste0("c", i)]]]]
      }

    }

    # If at least two sheets are filled in tosheet argument
    if (length(tosheet) > 1) {
      # We split this tosheet list according to each distint element
      listsplitted <- split(tosheet, match(tosheet, unique(unlist(tosheet))))
      # Each element of listsplitted is named with the name of each processed sheet
      listsplitted <- setNames(listsplitted,
                               unique(unlist(tosheet)))
      # We create namecurrentsheet as the name where df must be written
      namecurrentsheet <- names(listsplitted[[tosheet[[df]]]])
      # We create multipledfinsheet of the same length as listsplitted
      #  made up of booleans that indicate whether several df are in the same sheet
      multipledfinsheet <- lapply(listsplitted, function(x) length(x)>1)
    }

    # Useful print to debug
    # print(output_name)
    # print(listsplitted)
    # print(multipledfinsheet[[tosheet[[df]]]])
    # print(calcstartrow(which(namecurrentsheet == df)))

    # Use add_table() function to add each df in workbook
    add_table(
      Table = get(df),
      WbTitle = wb,
      SheetTitle = output[[df]][["sheet"]],
      TableTitle = output[[df]][["title"]],
      StartRow =
        # If the "tosheet" argument is not filled in
        # or if only one sheet is filled in "tosheet",
        # then we necessarily start writing from line 1
        if (length(tosheet) == 0 | length(tosheet) == 1) {
          1
          # Else if at least two sheets are filled in "tosheet" argument
          # and each df must be in different sheets
        } else if (length(tosheet) > 1 & isFALSE(multipledfinsheet[[tosheet[[df]]]])) {
          1
          # Else if at least two sheets are filled in "tosheet" argument
          # and at least two df must be in a same sheet
        } else if (length(tosheet) > 1 & isTRUE(multipledfinsheet[[tosheet[[df]]]])) {
          # StartRow is equal to 1 for first df
          # StartRow is equal to 11 + nrow(first df) for second df
          # StartRow is equal to 21 + nrow(first df) + nrow(second df) for third df
          calcstartrow(which(namecurrentsheet == df)) + calcskippedrow(mylist = get_object, x = which(namecurrentsheet == df))
        },
      StartCol = 1,
      FormatList = ColumnList,
      HeightTableTitle = 2,
      TableFootnote1 = output[[df]][["footnote1"]],
      TableFootnote2 = output[[df]][["footnote2"]],
      TableFootnote3 = output[[df]][["footnote3"]],
      MergeCol = output[[df]][["mergecol"]],
      ByGroup = output[[df]][["bygroup"]],
      GroupName = output[[df]][["groupname"]],
      asTable = asTable
    )

  }

  # Save workbook
  openxlsx::saveWorkbook(
    wb,
    file.path(
      path,
      paste0(filename,".xlsx")
    ),
    overwrite = TRUE
  )

  Sys.sleep(0.01)
  cli_alert_success("\nYour Excel file '{filename}.xlsx' is available in the folder '{path}'")

  # Open workbook automatically if automaticopen is TRUE
  if (isTRUE(automaticopen)) {
    openxlsx::openXL(file = file.path(
      path,
      paste0(filename,".xlsx")
    ))
  }
}
