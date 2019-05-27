%\VignetteIndexEntry{startup: The R Startup Process}
%\VignetteAuthor{Henrik Bengtsson}
%\VignetteKeyword{R}
%\VignetteKeyword{package}
%\VignetteKeyword{vignette}
%\VignetteKeyword{Rprofile}
%\VignetteKeyword{Renviron}
%\VignetteEngine{startup::selfonly}

## The R Startup Process

// https://github.com/wch/r-source/blob/R-3-5-branch/src/main/Rmain.c#L25-L31
File src/main/Rmain.c:
```c
int main(int ac, char **av)
{
    R_running_as_main_program = 1;

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/unix/system.c#L173-L515
    // Note: See below
    Rf_initialize_R(ac, av);

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/main.c#L1086-L1090
    // Note: See below
    Rf_mainloop(); /* does not return */
    return 0;
}
```


// https://github.com/wch/r-source/blob/R-3-5-branch/src/unix/system.c#L173-L515
File src/unix/system.c:

```c
int Rf_initialize_R(int ac, char **av)
{
    [...]

    ptr_R_EditFile = NULL; /* for future expansion */
    R_timeout_handler = NULL;
    R_timeout_val = 0;

    R_GlobalContext = NULL; /* Make R_Suicide less messy... */

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/main.c#L705-L720
    // Env vars: R_TRANSLATIONS
    // Files: RHOME/library/translations
    BindDomain(R_Home);

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/Renviron.c#L210-L234
    // Note: Only on Unix
    // Files: { R_HOME/etc/Renviron/<arch> or  R_HOME/etc/Renviron }
    process_system_Renviron();

    R_setStartTime();

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/startup.c#L150-L168
    R_DefParams(Rp);

    // Process command-line options
    [...]

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/startup.c#L268-L286
    // Sets: vsize, nsize, max_vsize, max_nsize, ppsize
    R_SetParams(Rp);

    if(!Rp->NoRenviron) {
        // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/Renviron.c#L240-L266
	// Files: R_ENVIRON, then R_HOME/etc/Renviron.site
	process_site_Renviron();

        // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/Renviron.c#L268-L303
	// Files: ./.Renviron, then ~/.Renviron
	process_user_Renviron();

        // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/startup.c#L177-L235
	// Env vars: R_MAX_VSIZE, R_VSIZE, R_NSIZE
	/* allow for R_MAX_[VN]SIZE and R_[VN]SIZE in user/site Renviron */
	R_SizeFromEnv(Rp);
	R_SetParams(Rp);
    }

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/unix/system.c#L111-L126
    // Env vars: R_HISTFILE, R_HISTSIZE
    // Files: ./.Rhistory
    R_setupHistory();
    
    if (R_RestoreHistory)
	Rstd_read_history(R_HistoryFile);
	
    fpu_setup(1);

    return(0);
}
```


// https://github.com/wch/r-source/blob/R-3-5-branch/src/main/main.c#L1086-L1090
```c
void mainloop(void)
{
    setup_Rmainloop();
    run_Rmainloop();
}
```


// https://github.com/wch/r-source/blob/R-3-5-branch/src/main/main.c#L722-L1061

```c
void setup_Rmainloop(void)
{
    [...]

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/connections.c#L5123-L5138
    // Connections: stdin, stdout, stderr
    InitConnections(); /* needed to get any output at all */

    /* Initialize the interpreter's internal structures. */
    // Setting locale (ala Sys.setlocale())
    // Env vars: LC_ALL, LC_CTYPE, LC_COLLATE, LC_TIME, LC_MONETARY, LC_MESSAGES, LC_PAPER, LC_MEASUREMENT
    /* We set R_ARCH here: Unix does it in the shell front-end */
    // Assigned env vars: R_ARCH

    /* make sure srand is called before R_tmpnam, PR#14381 */
    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/times.c#L149-L171
    // Note: Creates an initial seed from (time, pid)
    srand(TimeToSeed());

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/arithmetic.c#L161-L175
    // Note: Assigns internal R_NaInt, R_NaN, etc.
    InitArithmetic();
    
    InitParser();

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/sysutils.c#L1620-L1695
    // Note:
    // Env vars: TMPDIR then TMP then TEMP then /tmp (or R_USER on Windows)
    // Assign env var: R_SESSION_TMPDIR (= tempdir())
    InitTempDir(); /* must be before InitEd */

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/memory.c#L2068-L2169
    // Calls: init_gctorture(), init_gc_grow_settings()
    // Notes: Sets up internal R_TrueValue, R_FalseValue, etc.
    // /* InitMemory : Initialise the memory to be used in R. */
    // /* This includes: stack space, node space and vector space */
    InitMemory();
    
    InitStringHash(); /* must be before InitNames */

    // Note: Creates emptyenv() and baseenv()
    InitBaseEnv();

    // Note: Creats NA, "", etc.
    InitNames(); /* must be after InitBaseEnv to use R_EmptyEnv */

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/envir.c#L663-L687
    InitGlobalEnv();
    
    InitDynload();

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/options.c#L242-L363
    // Env vars: R_KEEP_PKG_SOURCE, R_C_BOUNDS_CHECK
    InitOptions();

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/edit.c#L71-L78
    InitEd();

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/devices.c#L507-L523
    InitGraphics();
    
    InitTypeTables(); /* must be before InitS3DefaultTypes */
    
    InitS3DefaultTypes();

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/print.c#L87-L108
    PrintDefaults();

    [...]

    /* Set up some global variables */
    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/platform.c#L199-L203
    // Assigns: .Machine, .Rplatform
    Init_R_Variables(baseEnv);

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/main.c#L686-L698
    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/main.c#L76-L119 <= R_ReplFile() 
    // Files: R_HOME/library/base/R/Rprofile
    R_LoadProfile(R_OpenSysInitFile(), baseEnv);
    
    /* These are the same bindings, so only lock them once */
    R_LockEnvironment(R_BaseNamespace, TRUE);
    
    /* At least temporarily unlock some bindings used in graphics */
    R_unLockBinding(R_DeviceSymbol, R_BaseEnv);
    R_unLockBinding(R_DevicesSymbol, R_BaseEnv);
    R_unLockBinding(install(".Library.site"), R_BaseEnv);

    if (strcmp(R_GUIType, "Tk") == 0) {
	snprintf(buf, PATH_MAX, "%s/library/tcltk/exec/Tk-frontend.R", R_Home);
	R_LoadProfile(R_fopen(buf, "r"), R_GlobalEnv);
    }

    if(!R_Quiet) PrintGreeting();

    R_LoadProfile(R_OpenSiteFile(), baseEnv);
    
    R_LockBinding(install(".Library.site"), R_BaseEnv);

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/unix/sys-unix.c#L67-L89
    // Env vars: R_PROFILE_USER, HOME
    // Files: ./.Rprofile then ~/.Rprofile
    R_LoadProfile(R_OpenInitFile(), R_GlobalEnv);

    /* This is where we try to load a user's saved data.
       The right thing to do here is very platform dependent.
       E.g. under Unix we look in a special hidden file and on the Mac
       we look in any documents which might have been double clicked on
       or dropped on the application.
    */

    // https://github.com/wch/r-source/blob/R-3-5-branch/src/main/saveload.c#L2218-L2239
    // Vars: sys.load.image
    // Files: ./.RData
    R_InitialData();

    /* Initial Loading is done.
       At this point we try to invoke the .First Function.
       If there is an error we continue. */
    // Calls: .GlobalEnv::.First() then {search()}:.First()

    /* Try to invoke the .First.sys function, which loads the default packages.
       If there is an error we continue. */
    // Calls: base::.First.sys()

    // Display any deferred warnings
	for(i = 0 ; i < ndeferred_warnings; i++)
	    warning(deferred_warnings[i]);
    }

    // Note: Initialize JIT
    _init_jit_enabled();
}
```
