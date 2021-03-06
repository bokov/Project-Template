# small utils ------------------------------------------------------------------

#' I'd rather not introduce a dependency for just one function, on the other
#' I trust Dr. Wickam & Co.'s code more than my own inexperienced stumblings so 
#' if coalesce is already available, I use that one.
#'  
if(!exists('coalesce')){
  coalesce <- function(...){
    Reduce(function(xx,yy) ifelse(is.na(xx),yy,xx),list(...))}
}

#' This function takes a list of package named, loads them if they are
#' available, otherwise attempts to install each one and then again 
#' attempts to load it.
instrequire <- function(pkglist
                        ,quietly=TRUE
                        ,repos=getOption('repos','https://cran.rstudio.com/')){
  pkgs_installed <- sapply(pkglist,require,character.only=T);
  if(length(pkgs_needed <- names(pkgs_installed[!pkgs_installed]))>0){
    install.packages(pkgs_needed,repos=repos,dependencies = T);
    pkgs_final <- sapply(pkgs_needed,require,character.only=T,quietly=quietly);
    if(!all(pkgs_final)){
      stop(c('the following required packages could not be installed:\n'
             ,paste0(names(pkgs_final[!pkgs_final]),collapse = ', ')));
    }
  };
}


#' Function for appending or replacing attributes of any object 
#' within a pipeline
#'
#' @param xx        Object whose attributes to modify and then return the object
#' @param rep.attrs Named list of attributes to create or replace
#' @param app.attrs Named list of attributes to create or append to
#'
#' @return The object `xx` with modified attributes
#' @export
#'
#' @examples
with_attrs<-function(xx,rep.attrs=list(),app.attrs=list()){
  attrs <- attributes(xx); if(is.null(attrs)) attrs<-list();
  for(ii in names(rep.attrs)) attrs[[ii]] <- rep.attrs[[ii]];
  for(ii in names(app.attrs)) attrs[[ii]] <- c(attrs[[ii]],app.attrs[[ii]]);
  attributes(xx) <- attrs;
  xx;
}

#' takes input and returns it with a comment attribute
cm <- with_cm <- function(xx,comment=NULL,append=T
                          ,transf=stringr::str_squish){
  if(!is.null(transf)) comment <- transf(comment);
  if(append) with_attrs(xx,app.attrs=list(comment=comment)) else {
    with_attrs(xx,rep.attrs=list(comment=comment));
  }
}

#' Take an object name \code{obj}, check to see if it  exists in environment \code{env}
#' and if it does not, run \code{expression} \code{EXPR} and assign its result to \code{obj}
#'
#' @param obj   A \code{character} string (required) naming the variable in env
#'   to which the results of running \code{EXPR} will be assigned.
#' @param EXPR  An \code{expression} to execute and assign to the object named
#'   by \code{obj} if it doesn't already exist.
#' @param env   An \code{environment} to check for the existence of \code{obj}
#'   and where to create it if it doesn't exist.
#'
#' @return Does not return anything.
#'
#' @examples `checkrun('dat3',{group_by(dat1,idn_mrn) %>% summarise_all(first)});`
checkrun <- function(obj,EXPR,env=as.environment(-1)){
  env<-env;
  if(length(ls(env,all=T,pattern=obj))==0){
    browser();
  }
}

getCall.list <- getCall.data.frame <- getCall.gg <- function(xx) {attr(xx,'call')};

# why not update calls?
update.call <- function(xx,...){
  dots <- list(...);
  for(ii in names(dots)) xx[[ii]] <- dots[[ii]];
  xx;
}

#' Stack a vector to form a matrix with repeating rows, with optional 
#' column names and transformation
#'
#' @param  vv    A vector which will become the row of a matrix
#' @param  nr    Number of (identical) rows this matrix will contain
#' @param  trans An optional function that can take a matrix as its 
#'              sole argument. Useful functions include `as.data.frame()`
#'              `as_tibble()` and `as.table()`
#' @return A matrix, unless the function specified in the `trans` argument
#'         causes the output to be something else.
#' @export 
#'
#' @examples 
#' vec2m(1:10,5);
#' vec2m(1:10,5,tr=data.frame);
#' vec2m(setNames(1:12,month.name),3);
vec2m <- function(vv,nr=1,trans=identity) {
  return(trans(matrix(as.matrix(c(vv)),nrow=nr,ncol=length(vv),byrow=T
                      ,dimnames=list(NULL,names(vv)))));
}

#' returns call with ALL arguments specified, both the defaults and those
#' explicitly provided by the user
fullargs <- function(syspar=sys.parent(),env=parent.frame(2L),expand.dots=TRUE){
  fn <- sys.function(syspar);
  frm <- formals(fn);
  cll <- match.call(fn,sys.call(syspar),expand.dots = expand.dots,envir = env);
  defaults <- setdiff(names(frm),c(names(cll),'...'));
  for(ii in defaults) cll[[ii]] <- frm[[ii]];
  return(cll);
}

#' Take a set of objects coercible to matrices and perform sprintf on them while
#' preserving their dimensions (obtained from the first argument of ...)
mprintf <- function(fmt,...,flattenmethod=1){
  dots <- list(...);
  out<-dots[[1]];
  # if factors not converted to characters, those cells will come out as NA
  if(is.factor(out)) out <- as.character(out) else if(is.list(out)){
    for(ii in seq_along(out)) if(is.factor(out[[ii]])) {
      out[[ii]]<-as.character(out[[ii]])}}
  if(is.null(nrow(out))) {
    warning('Converting output to matrix. Might be errors.');
    outnames<-names(out);
    out <- t(matrix(out));
    try(colnames(out)<-outnames);
  }
  for(ii in seq_along(dots)) dots[[ii]] <- c(if(flattenmethod==1) {
    unlist(dots[[ii]])} else if(flattenmethod==2){
      sapply(dots[[ii]],as.character)});
  vals <- do.call(sprintf,c(fmt,dots));
  for(ii in seq_len(nrow(out))) for(jj in seq_len(ncol(out))) {
    out[ii,jj] <-matrix(vals,nrow=nrow(out))[ii,jj]};
  out;
  }


# renaming and remapping  ------------------------------------------------------
#' A function to re-order and/or rename the levels of a factor or 
#' vector with optional cleanup.
#'
#' @param xx            a vector... if not a factor will be converted to 
#'                      one
#' @param lookuptable   matrix-like objects where the first column will
#'                      be what to rename FROM and the second, what to
#'                      rename TO. If there is only one column or if it's
#'                      not matrix-like, the levels will be set to these
#'                      values in the order they occur in `lookuptable`.
#'                      If there are duplicated values in the first column
#'                      only the first one gets used, with a warning.
#'                      Duplicate values in the second column are allowed 
#'                      and are a feature.
#' @param reorder       Whether or not to change the order of the factor
#'                      levels to match those in `lookuptable`. True by
#'                      default (logical). By default is `TRUE`, is set to
#'                      `FALSE` will try to preserve the original order of
#'                      the levels.
#' @param unmatched     Scalar value. If equal to -1 and `reorder` is `TRUE` 
#'                      then unmatched original levels are prepended to the 
#'                      matched ones in their original order of occurence. If 
#'                      equal to 1, then appended in their original order of 
#'                      occurrence. If some other value, then they are all 
#'                      binned in one level of that name. The (empty) new ones 
#'                      always go to the end.
#' @param droplevels    Drop unused levels from the output factor (logical)
#' @param case          Option to normalize case (`'asis'`` leaves it as it was)
#'                      before attempting to match to `lookuptable`. One value 
#'                      only
#' @param mapnato       If the original levels contain `NA`s, what they should 
#'                      be instead. They stay `NA` by default.
#' @param remove        Vector of strings to remove from all level names (can
#'                      be regexps) before trying to match to `lookuptable`.
#' @param otherfun      A user-specified function to make further changes to
#'                      the original level names before trying to match and
#'                      replace them. Should expect to get the output from
#'                      `levels(xx)` as its only argument.
#' @param spec_mapper   A constrained lookup table specification that includes
#'                      a column named `varname` in addition to the two columns
#'                      that will become `from` and `to`. This is for extra
#'                      convenience in projects that use such a table. If you
#'                      aren't working on a project that already follows this
#'                      convention, you should ignore this parameter.
#' @param var           What value should be in the `varname` column of 
#'                      `spec_mapper`
#' @param fromto        Which columns in the `spec_mapper` should become the 
#'                      `from` and `to` columns, respectively. Vector of length
#'                      2, is `c('code','label')` by default.
factorclean <- function(xx,lookuptable,reorder=T,unmatched=1
                        ,droplevels=F,case=c('asis','lower','upper')
                        ,mapnato=NA,remove='"',otherfun=identity
                        ,spec_mapper,var,fromto=c('code','label')){
  if(!is.factor(xx)) xx <- factor(xx);
  lvls <- levels(xx);
  lvls <- switch (match.arg(case)
                   ,asis=identity,lower=tolower,upper=toupper)(lvls) %>% 
    submulti(cbind(remove,'')) %>% otherfun;
  levels(xx) <- lvls;
  # Check to see if spec_mapper available.
  if(!missing(spec_mapper)&&!missing(var)){
    lookuptable <- subset(spec_mapper,varname==var)[,fromto];
  }
  # The assumption is that if you're passing just a vector or something like
  # it, then you want to leave the level names as-is and just want to change
  # the ordering
  if(is.null(ncol(lookuptable))) lookuptable <- cbind(lookuptable,lookuptable);
  # can never be too sure what kind of things with rows and columns are getting 
  # passed, so coerce this to a plain old vanilla data.frame
  lookuptable <- data.frame(lookuptable[,1:2]) %>% setNames(c('from','to'));
  if(length(unique(lookuptable[,1]))!=nrow(lookuptable)) {
    lookuptable <- lookuptable[match(unique(lookuptable$from),lookuptable$from),];
    warning("You have duplicate values in the first (or only) column of your 'lookuptable' argument. Only the first instances of each will be kept");
  }
  if(reorder){
    extras <- data.frame(from=lvls,to=NA,stringsAsFactors = F) %>%
      subset(!from %in% lookuptable$from);
    lookupfinal <- if(unmatched==-1) rbind(extras,lookuptable) else {
      rbind(lookuptable,extras)};
  } else {
    lookupfinal <- left_join(data.frame(from=lvls,stringsAsFactors = F)
                             ,lookuptable,by='from') %>% 
      rbind(subset(lookuptable,!from%in%lvls));
  }
  # if the 'unmatched' parameter has the special value of -1 or 1, leave the 
  # original names for the unmatched levels. Otherwise assign them to the bin
  # this parameter specifies
  lookupfinal$to <- with(lookupfinal,if(unmatched %in% c(-1,1)){
    ifelse(is.na(to),from,to)} else {ifelse(is.na(to),unmatched,to)});
  # Warning: not yet tested on xx's that are already factors and have an NA
  # level
  lookupfinal$to <- with(lookupfinal,ifelse(is.na(from),mapnato,to));
  out <- factor(xx,levels=lookupfinal$from);
  levels(out) <- lookupfinal$to;
  if(droplevels) droplevels(out) else out;
}


#' into the specified existing or new level. That level is listed last
#' in the resulting factor.
#' @param xx A \code{vector} (required).
#' @param topn \code{numeric} for the top how many levels to keep (optional, default =4)
#' @param binto \code{character} which new or existing level to dump the other values in
cl_bintail <- function(xx,topn=4,binto='other'){
  if(!is.factor(xx)) xx <- factor(xx);
  counts <- sort(table(xx),decreasing = T);
  if(is.numeric(binto)) binto <- names(counts)[binto];
  keep <- setdiff(names(counts)[1:min(length(counts),topn)],binto);
  droplevels(
    factor(
      ifelse(
        xx %in% keep, as.character(xx), binto
        ),levels=c(keep,binto)));
}


#' Take a character vector and perform multiple search-replace 
#' operations on it.
#' @param xx A \code{vector} of type \code{character} (required)
#' @param searchrep A \code{matrix} with two columns of type \code{character} (required). The left column is the pattern and the right, the replacement.
#' @param method One of 'partial','full', or 'exact'. Controls whether to replace only the matching regexp, replace the entire value that contains a matching regexp, or replace the entire value if it's an exact match.
submulti <- function(xx,searchrep
                     ,method=c('partial','full','exact'
                               ,'starts','ends','startsends')){
  # if no method is specified by the user, this makes it take the first value
  # if a method is only partially written out, this completes it, and if the
  # method doesn't match any of the valid possibilities this gives an informativ
  # error message
  method<-match.arg(method);
  # if passed a single vector of length 2 make it a matrix
  if(is.null(dim(searchrep))&&length(searchrep)==2) searchrep<-rbind(searchrep);
  # rr is a sequence of integers spanning the rows of the searchrep matrix
  rr <- 1:nrow(searchrep);
  # oo will hold the result that this function will return
  oo <- xx;
  switch(method
         ,partial = {for(ii in rr)
           oo <- gsub(searchrep[ii,1],searchrep[ii,2],oo)}
         ,full =    {for(ii in rr)
           oo[grepl(searchrep[ii,1],oo)]<-searchrep[ii,2]}
         ,exact = {for(ii in rr)
           oo[grepl(searchrep[ii,1],oo,fixed=T)]<-searchrep[ii,2]}
           #oo <- gsub(searchrep[ii,1],searchrep[ii,2],oo,fixed = T)}
         ,starts = {for(ii in rr)
           oo <- gsub(paste0('^',searchrep[ii,1]),searchrep[ii,2],oo)}
         ,ends = {for(ii in rr)
           oo <- gsub(paste0(searchrep[ii,1],'$'),searchrep[ii,2],oo)}
         ,startsends = {for(ii in rr)
           oo <- gsub(paste0('^',searchrep[ii,1],'$'),searchrep[ii,2],oo)}
  );
  oo;
}

#' Take a data.frame or character vector and a vector of grep targets and return
#' the values that match (for data.frame, column names that match). If no 
#' patterns given just returns the names
#' @param xx A \code{data.frame} or character vector (required)
#' @param patterns A character vector of regexp targets to be OR-ed
grepor <- function(xx,patterns='.') {
  if(is.list(xx)) xx <-names(xx);
  grep(paste0(patterns,collapse='|'),xx,val=T);
}

#' Usage: `xx<-mapnames(xx,lookup)` where lookup is a named character vector
#' the names of the elements in the character vector are what you are renaming
#' things TO and the values are what needs to be matched, i.e. what renaming things
#' FROM. If you set namesonly=T then it just returns the names, not the original
#' object.
mapnames<-function(xx,lookup,namesonly=F,...){
  xnames <- names(xx);
  idxmatch <- na.omit(match(xnames,lookup));
  newnames <- names(lookup)[idxmatch];
  if(namesonly) return(newnames);
  names(xx)[xnames %in% lookup] <- newnames;
  xx;
}

#' Example of using R methods dispatch
#' 
#' The actual usage is: `truthy(foo)` and `truthy()` itself figures
#' out which method to actually dispatch.
truthy <- function(xx,...) UseMethod('truthy');
truthy.logical <- function(xx,...) xx;
truthy.factor <- function(xx,...) truthy.default(as.character(xx),...);
truthy.numeric <- function(xx,...) xx>0;
truthy.default <- function(xx,truewords=c('TRUE','true','Yes','T','Y','yes','y')
                           ,...) xx %in% truewords;
truthy.data.frame <- function(xx,...) as.data.frame(lapply(xx,truthy,...));

# table utilities --------------------------------------------------------------
#' Sumarize a table column
colinfo <- function(col){
  list(class=class(col)[1]
       ,isnum=is.numeric(col)
       ,nmissing=sum(is.na(col))
       ,fracmissing=mean(is.na(col)))}

#' Returns a vector of column names that contain data elements of a particular type
#' as specified by the user: "integer","POSIXct" "POSIXt", "numeric", "character", 
#' "factor" and "logical". 
vartype <- function(dat, ctype) {
  xx <- unlist(sapply(dat, class));
  idx <- which(xx %in% ctype);
  res <- names(xx)[idx];
  return(res)
}

#' Not yet ready:
#' 
# rebuild_dct <- function(dat=dat0,rawdct=dctfile_raw,tpldct=dctfile_tpl,debuglev=0
#                         ,tread_fun=read_csv,na='',searchrep=c()){
#   out <- names(dat)[1:8] %>% 
#     tibble(colname=.,colname_long=.,rule='demographics') %>% 
#     rbind(tread(rawdct,tread_fun,na = na));
#   if(length(na.omit(out$colname))!=length(unique(na.omit(out$colname)))){
#     stop('Invalid data dictionary! Duplicate values in colname column');}
#   out$colname <- tolower(out$colname);
#   #dct0 <- subset(dct0,dct0$colname %in% names(dat0));
#   shared <- intersect(names(dat),out$colname);
#   out[out$colname %in% shared,'class'] <- lapply(dat0[,shared],class) %>% sapply(head,1);
#   out$colsuffix <- gsub('^v[0-9]{3}','',out$colname);
#   if(debug>0) .outbak <- out;
#   # end debug
#   out <- left_join(out,tpl<-tread(tpldct,tread_fun,na=na)
#                    ,by=c('colsuffix','colname_long'));
#   # debug
#   if(debug>0){
#     if(nrow(out)!=nrow(.outbak)) 
#       stop('Number of rows changed in dct0 after join');
#     if(!identical(out$colname,.outbak$colname)) 
#       stop('colname values changed in dct0 after join');
#   }
#   # find the dynamic named vars in tpl
#   outappend <- subset(tpl,!varname %in% out$varname);
#   # make sure same columns exist
#   outappend[,setdiff(names(out),names(outappend))] <- NA;
#   out <- rbind(out,outappend[,names(out)]);
#   # end debug
#   out$c_all <- TRUE;
#   # replace strings if needed
#   if(!missing(searchrep)) {
#     out$colname_long <- submulti(out$colname_long,searchrep);}
#   return(out);
# }



# string hacking ---------------------------------------------------------------
#' Fancy Span (or any other special formatting of strings)
#' 
fs <- function(str,text=str,url=paste0('#',gsub('[^_a-z0-9]','-',tolower(str)))
               ,tooltip=alist(str),class='fl'
               # %1 = text, %2 = url, %3 = class, %4 = tooltip
               # TODO: %5 = which position 'str' occupies in fs_reg if 
               #       applicable and if not found, append 'str'
               ,template='[%1$s]: %2$s "%4$s"\n'
               # Turns out that the below template will generate links, but they
               # only render properly for HTML output because pandoc doesn't 
               # interpret them. However, if we use the markdown implicit link
               # format (https://pandoc.org/MANUAL.html#reference-links) we 
               # don't have to wrap links in anything, but we _can_ use fs()
               # with the new template default above to generate a block of 
               # link info all at once in the end. No longer a point in using
               # the fs_reg feature for this case, the missing links will be
               # easy to spot in the output hopefully
               #,template="<a href='%2$s' class='%3$s' title='%4$s'>%1$s</a>"
               ,dct=dct0,col_tooltip='colname_long',col_class='',col_url=''
               ,col_text='',match_col=c('varname','colname'),fs_reg=NULL
               ,retfun=cat
               #,fs_reg='fs_reg'
               ,...){
  # if a data dictionary is specified use that instead of the default values 
  # for arguments where the user has not explicitly provided values (if there
  # is no data dictionary or if the data dictionary doesn't have those columns,
  # fall back on the default values)
  if(is.data.frame(dct) && 
     length(match_col<-intersect(match_col,names(dct)))>0){
    dctinfo <- dct[match(str,do.call(coalesce,dct[,match_col])),];
     #!all(is.na(dctinfo <- dct[which(dct[[match_col]]==str)[1],]))){
    if(missing(tooltip) #&& 
      #length(dct_tooltip<-na.omit(dctinfo[[col_tooltip]]))==1) {
      #tooltip <- dct_tooltip;}
    ){tooltip <- do.call(coalesce,c(dctinfo[,col_tooltip],tooltip,''))};
    if(missing(text) && 
       length(dct_text<-na.omit(c(dctinfo[[col_text]],NA)))==1) {
      text <- dct_text;}
    if(missing(url) && 
       length(dct_url<-na.omit(c(dctinfo[[col_url]],NA)))==1) {
      url <- dct_url;}
    if(missing(class) && 
       length(dct_class<-na.omit(c(dctinfo[[col_class]],NA)))==1) {
      class <- dct_class;}
  } else dctinfo <- data.frame(NA);
  out <- sprintf(rep(template,nrow(dctinfo)),text,url,class,tooltip,...);
  # register each unique str called by fs in a global option specified by 
  # fs_register
  if(!is.null(fs_reg)) {
    dbg<-try(do.call(options,setNames(list(union(getOption(fs_reg),str))
                                      ,fs_reg)));
    if(is(dbg,'try-error')) browser();
    }
  retfun(out);
}
