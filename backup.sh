#!/bin/bash
. config.ini
#get all the stored procedures and functions 
MYSQL_CONN="-h${hostname} -u${username} -p${password}"
SQLSTMT="SELECT COUNT(1) FROM mysql.proc"
PROCCOUNT=`mysql ${MYSQL_CONN} -ANe"${SQLSTMT}" | awk '{print $1}'`
if [ ${PROCCOUNT} -eq 0 ] ; then exit ; fi
SPLIST=""
for DBSP in `mysql ${MYSQL_CONN} -ANe"SELECT CONCAT(type,'@',db,'.',name) FROM mysql.proc"`
do
    SPLIST="${SPLIST} ${DBSP}"
done
for TYPEDBSP in `echo "${SPLIST}"`
do
    TYPE=`echo "${TYPEDBSP}" | sed 's/@/ /' | sed 's/\./ /' | cut -d ' ' -f1`
    DB=`echo "${TYPEDBSP}" | sed 's/@/ /' | sed 's/\./ /' | cut -d ' ' -f2`
    SP=`echo "${TYPEDBSP}" | sed 's/@/ /' | sed 's/\./ /' | cut -d ' ' -f3`
    SQLSTMT=`echo "SHOW CREATE ${TYPEDBSP}\G" | sed 's/@/ /'`
    mkdir -p ${DB}/${TYPE}
    SPFILE=${DB}_${SP}.sql
    SPTEMP=${DB}_${SP}.tmp
    echo ${TYPE} Echoing ${SQLSTMT} into ${SPFILE}
    mysql ${MYSQL_CONN} -ANe"${SQLSTMT}" > ${SPFILE}
    #
    # Remove Top 3 Lines
    #
    LINECOUNT=`wc -l < ${SPFILE}`
    (( LINECOUNT -= 3 ))
    tail -${LINECOUNT} < ${SPFILE} > ${SPTEMP}
    #
    # Remove Bottom 3 Lines
    #
    LINECOUNT=`wc -l < ${SPTEMP}`
    (( LINECOUNT -= 3 ))
    head -${LINECOUNT} < ${SPTEMP} > ${SPFILE}

    #add drop and delimiter query
    echo "DROP ${TYPE} IF EXISTS ${SP};

DELIMITER ;; 
" | cat - ${SPFILE} > ${SPTEMP}
    echo ";;
DELIMITER ;"| cat ${SPTEMP} - > ${DB}/${TYPE}/${SPFILE}
    rm -f ${SPFILE}
    rm -f ${SPTEMP}
done


#get triggers
for DB in in `mysql ${MYSQL_CONN} -ANe"${SQLSTMT}"`
do
    echo Trigger dump on ${DB}
    GET_TRIGGERS="SHOW TRIGGERS FROM ${DB};"
    mysql ${MYSQL_CONN} -NBe "${GET_TRIGGERS}" | while read -r trigger event table statement timing created sql_mode definer character_set_clinet collation_connection;
    do
        mkdir -p ${DB}/TRIGGERS/
        TGF=${trigger}.sql #trigger file name
        TGF_TMP=${trigger}.tmp #trigger temp file name

        GET_TRIGGER="SHOW CREATE TRIGGER ${DB}.${trigger}"
        echo ${DB}.${trigger} echoing ${GET_TRIGGER}into /${DB}/TRIGGER/${TGF}
        mysql ${MYSQL_CONN} -ANe"${GET_TRIGGER}\G" > ${TGF}
        
        # Remove Top 3 Lines
        #
        LINECOUNT=`wc -l < ${TGF}`
        (( LINECOUNT -= 3 ))
        tail -${LINECOUNT} < ${TGF} > ${TGF_TMP}
        #
        # Remove Bottom 3 Lines
        #
        LINECOUNT=`wc -l < ${TGF_TMP}`
        (( LINECOUNT -= 3 ))
        head -${LINECOUNT} < ${TGF_TMP} > ${TGF}
        rm ${TGF_TMP}
        mv ${TGF} ${DB}/TRIGGERS/${TGF}
    done
done

# if there is a difference in the git then push to server with time stamp
###########################
# diff=`git status --short`
# # echo $diff
# if [ ! -z "${diff}" ] ; then
#     echo 'diff'
#     git add -A
#     DATE=`date "+%Y-%m-%d %H:%M:%S"`
#     git commit -m "${DATE}"
#     git pull origin master
#     git push origin master
# fi
exit 1;
