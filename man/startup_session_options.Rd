% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/startup_session_options.R
\name{startup_session_options}
\alias{startup_session_options}
\title{Record R session information as options}
\usage{
startup_session_options(action = c("update", "overwrite", "erase"))
}
\arguments{
\item{action}{If \code{"update"} or \code{"overwrite"}, \R options
\code{"startup.session.*"} are set.  If \code{"update"}, then such options that are
not already set are updated.  If \code{"erase"}, any existing
\code{"startup.session.*"} options are removed.}
}
\value{
Returns invisibly a named list of the options prefixed
\code{"startup.session."}:
\describe{
\item{\code{startup.session.startdir}}{(character) the working directory when
the \pkg{startup} was first loaded.  If \code{startup::startup()} is called
at the very beginning of the \file{.Rprofile} file, this is also the
directory that the current \R session was launched from.}
\item{\code{startup.session.starttime}}{(POSIXct) the time when the
\pkg{startup} was first loaded.}
\item{\code{startup.session.id}}{(character) a unique ID for the current \R
session.}
\item{\code{startup.session.dumpto}}{(character) a session-specific name that
can be used for argument \code{dumpto} of \link[utils:debugger]{dump.frames()}
(also for dumping to file).}
}
}
\description{
Record R session information as options
}
\examples{
opts <- startup::startup_session_options()
opts

}
