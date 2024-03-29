#' Restarts R
#'
#' Restarts \R by quitting the current \R session and launching a new one.
#'
#' @param status An integer specifying the exit code of the current
#' \R session.
#' 
#' @param workdir The working directory where the new \R session should
#' be launched from.  If `NULL`, then the working directory that was in
#' place when the \pkg{startup} package was first loaded.  If using
#' `startup::startup()` in an \file{.Rprofile} startup file, then this
#' is likely to record the directory from which \R itself was launched from.
#' 
#' @param rcmd A character string specifying the command for launching \R.
#' The default is the same as used to launch the current \R session, i.e.
#' \code{\link[base:commandArgs]{commandArgs()[1]}}.
#'
#' @param args A character vector specifying zero or more command-line
#' arguments to be appended to the system call of \code{rcmd}.
#'
#' @param envvars A named character vector of environment variables to
#' be set when calling \R.
#'
#' @param as A character string specifying a predefined setups of `rcmd`,
#' `args`, and `envvars`.  For details, see below.
#' 
#' @param quiet Should the restart be quiet or not?
#' If `NA` and `as == "current"`, then `quiet` is `TRUE` if the current
#' \R session was started quietly, otherwise `FALSE`.
#' 
#' @param debug If `TRUE`, debug messages are outputted, otherwise not.
#'
#' @section Predefined setups:
#' Argument `as` may take the following values:
#' \describe{
#'  \item{\code{"current"}:}{(Default) A setup that emulates the setup of the
#'   current \R session as far as possible by relaunching \R with the same
#'   command-line call (= [base::commandArgs()]).
#'  }
#'  \item{\code{"specified"}:}{According to `rcmd`, `args`, and `envvars`.}
#'  \item{\code{"R CMD build"}:}{A setup that emulates
#'   [`R CMD build`](https://github.com/wch/r-source/blob/R-3-4-branch/src/scripts/build)
#'   as far as possible.
#'  }
#'  \item{\code{"R CMD check"}:}{A setup that emulates
#'   [`R CMD check`](https://github.com/wch/r-source/blob/R-3-4-branch/src/scripts/check)
#'   as far as possible, which happens to be identical to the
#'  `"R CMD build"` setup.
#'  }
#'  \item{\code{"R CMD INSTALL"}:}{A setup that emulates
#'   [`R CMD INSTALL`](https://github.com/wch/r-source/blob/R-3-4-branch/src/scripts/INSTALL)
#'   as far as possible.
#'  }
#' }
#' If specified, command-line arguments in `args` and environment variables
#' in `envvars` are _appended_ accordingly.
#'
#' @section Known limitations:
#' It is _not_ possible to restart an \R session running in _RGui_ on
#' Microsoft Windows using this function.
#' 
#' It is _not_ possible to restart an \R session in the RStudio _Console_
#' using this function.  However, it does work when running \R in the
#' RStudio _Terminal_.
#' 
#' RStudio provides `rstudioapi::restartSession()` which will indeed restart
#' the RStudio Console.  However, it does not let you control how \R is
#' restarted, e.g. with what command-line options and what environment
#' variables.  Importantly, the new \R session will have the same set of
#' packages loaded as before, the same variables in the global environment,
#' and so on.
#'
#' @examples
#' \dontrun{
#'   ## Relaunch R with debugging of startup::startup() enabled
#'   startup::restart(envvars = c(R_STARTUP_DEBUG = TRUE))
#'
#'   ## Relaunch R without loading user Rprofile files
#'   startup::restart(args = "--no-init-file")
#'
#'   ## Mimic 'R CMD build' and 'R CMD check'
#'   startup::restart(as = "R CMD build")
#'   startup::restart(as = "R CMD check")
#'   ## ... which are both short for
#'   startup::restart(args = c("--no-restore"),
#'                    envvars = c(R_DEFAULT_PACKAGES="", LC_COLLATE="C"))
#' }
#'
#' @export
restart <- function(status = 0L,
                    workdir = NULL,
                    rcmd = NULL, args = NULL, envvars = NULL,
                    as = c("current", "specified",
                           "R CMD build", "R CMD check", "R CMD INSTALL"),
                    quiet = FALSE,
                    debug = NA) {
  debug(debug)
  logf("Restarting R ...")

  ## The RStudio Console cannot be restarted this way
  if (is_rstudio_console()) {
    stop("R sessions run via the RStudio Console cannot be restarted using startup::restart(). It is possible to restart R in an RStudio Terminal. To restart an R session in the RStudio Console, use rstudioapi::restartSession().")
  }

  ## The Windows RGui cannot be restarted this way
  if (sysinfo()$gui == "Rgui") {
    stop("R sessions run via the Windows RGui cannot be restarted using startup::restart().")
  }
  
  if (is.null(workdir)) {
    workdir <- startup_session_options()$startup.session.startdir
  }
  if (!is_dir(workdir)) {
    stop("Argument 'workdir' specifies a non-existing directory: ",
         squote(workdir))
  }
  
  cmdargs <- commandArgs()

  if (is.null(rcmd)) rcmd <- cmdargs[1]
  stop_if_not(length(rcmd) == 1L, is.character(rcmd))
  rcmd_t <- Sys.which(rcmd)
  if (rcmd_t == "") {
    stop("Argument 'rcmd' specifies a non-existing command: ", squote(rcmd))
  }

  as <- match.arg(as)
  if (as == "specified") {
  } else if (as == "current") {
    if (is.null(args)) {
      ## WORKAROUND: When running 'radian', commandArgs() does not
      ## reflect how it was started.
      ## https://github.com/randy3k/radian/issues/23#issuecomment-375078246
      if (is_radian()) {  
        args <- Sys.getenv("RADIAN_COMMAND_ARGS")
      } else {
        args <- cmdargs[-1]
      }
    }
    ## Restart quietly if current session was start quietly?
    if (is.na(quiet)) quiet <- any(args %in% c("--quiet", "-q"))
  } else if (as %in% c("R CMD build", "R CMD check")) {
    ## Source:
    ##  - src/scripts/build
    ##  - src/scripts/check
    ## Also '--slave', but we disable that for now to make it clear
    ## that the session is restarted.

    if (is_radian()) {
      stop(sprintf("startup::restart(as = %s) is not supported when running R via radian", dQuote(as)))
    }
    
    args <- c("--no-restore", args)
    envvars <- c(R_DEFAULT_PACKAGES = "", LC_COLLATE = "C", envvars)
  } else if (as %in% c("R CMD INSTALL")) {
    ## Source:
    ##  - src/scripts/INSTALL
    ## Also '--slave', but we disable that for now to make it clear
    ## that the session is restarted.

    if (is_radian()) {
      stop(sprintf("startup::restart(as = %s) is not supported when running R via radian", dQuote(as)))
    }
    
    vanilla_install <- nzchar(Sys.getenv("R_INSTALL_VANILLA"))
    if (vanilla_install) {
      args <- c("--vanilla", args)
    } else {
      args <- c("--no-restore", args)
    }
    envvars <- c(R_DEFAULT_PACKAGES = "", LC_COLLATE = "C", envvars)
  } else {
    stop("Unknown value on argument 'as': ", squote(as))
  }

  ## Restart quietly or not?
  if (as != "specified") {
    if (quiet) {
      if (is_radian()) {
        ## Only radian (>= 0.2.8) supports '--quiet'
        ## Comment: prior to v0.3.0, radian was actually called 'rtichoke',
        ## so let's just require 'radian' here.
        version <- Sys.getenv("RADIAN_VERSION")
        stopifnot(nzchar(version))
        version <- package_version(version)
        if (version < "0.2.8") {
          stop("startup::restart(quiet = TRUE) requires radian (>= 0.2.8)")
        }
      }
      args <- c("--quiet", args)
    } else {
      args <- setdiff(args, "--quiet")
    }
  }
  
  if (!is.null(envvars) && length(envvars) > 0L) {
    stop_if_not(!is.null(names(envvars)))
    envvars <- sprintf("%s=%s", names(envvars), shQuote(envvars))
  }

  ## To please R CMD check
  envir <- globalenv()

  ## Make sure to call existing .Last(), iff any
  has_last <- exists(".Last", envir = envir, inherits = FALSE)
  if (has_last) {
    last_org <- get(".Last", envir = envir, inherits = FALSE)
  } else {
    last_org <- function() NULL
  }

  logf("- R executable: %s", rcmd)
  logf("- Command-line arguments: %s", paste(args, collapse = " "))
  logf("- Environment variables: %s", paste(envvars, collapse = " "))
  
  assign(".Last", function() {
    last_org()
    system2(rcmd, args = args, env = envvars)
  }, envir = envir)

  logf("- quitting current R session")
  if (has_last) logf("- existing .Last() will be acknowledged")
  logf("Restarting R ... done")

  setwd(workdir)
  quit(save = "no", status = status, runLast = TRUE)
}
