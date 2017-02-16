#!/bin/bash

TMPDIR=/tmp/librecat-$$
CMD=$1

case "${CMD}" in
    create)
        echo "Creating index..."
        echo "user..."
        carton exec bin/librecat user add devel/researcher.yml
        echo "publication..."
        carton exec bin/librecat publication add devel/publications.yml
        echo "department..."
        carton exec bin/librecat department add devel/department.yml
        echo "project..."
        carton exec bin/librecat project add devel/project.yml
        echo "Done"
        ;;
    drop)
        echo "Dropping index.."
        echo "user..."
        carton exec bin/librecat delete search --bag researcher
        echo "publication..."
        carton exec bin/librecat delete search --bag publication
        echo "department..."
        carton exec bin/librecat delete search --bag department
        echo "research_group..."
        carton exec bin/librecat delete search --bag research_group
        echo "project..."
        carton exec bin/librecat delete search --bag project
        echo "Done"
        ;;
    drop_backup)
        echo "Dropping backup.."
        echo "ids..."
        carton exec bin/librecat delete default --bag data
        echo "researcher..."
        carton exec bin/librecat delete backup  --bag researcher
        echo "publication..."
        carton exec bin/librecat delete backup  --bag publication
        echo "department..."
        carton exec bin/librecat delete backup  --bag department
        echo "project..."
        carton exec bin/librecat delete backup  --bag project
        echo "research_group..."
        carton exec bin/librecat delete backup  --bag research_group
        echo "Done"
        ;;
    drop_version)
        echo "Dropping backup.."
        echo "user..."
        carton exec bin/librecat delete backup  --bag user_version
        echo "publication..."
        carton exec bin/librecat delete backup  --bag publication_version
        echo "department..."
        carton exec bin/librecat delete backup  --bag department_version
        echo "project..."
        carton exec bin/librecat delete backup  --bag project_version
        echo "research_group..."
        carton exec bin/librecat delete backup  --bag research_group_version
        echo "Done"
        ;;
    export)
        echo "Exporting index..."

        mkdir -p ${TMPDIR}

        echo "user..."
        carton exec bin/librecat user list > ${TMPDIR}/researcher.yml
        echo "publication..."
        carton exec bin/librecat publication list > ${TMPDIR}/publications.yml
        echo "department..."
        carton exec bin/librecat department list > ${TMPDIR}/department.yml
        echo "project..."
        carton exec bin/librecat project list > ${TMPDIR}/project.yml
        echo "research_group..."
        carton exec bin/librecat research_group list > ${TMPDIR}/research_group.yml

        cd ${TMPDIR}

        OUTFILE=/tmp/librecat-index-export.$$.zip
        zip ${OUTFILE}  *

        cd -

        rm -rf ${TMPDIR}

        echo "Output ready in: ${OUTFILE}"
        echo "Done"
        ;;
    import)
        echo "Importing index..."
        FILE=$2

        if [ "${FILE}" == "" ]; then
            echo "Need a zipfile"
            echo "usage: $0 index zipfile"
            exit 1
        fi

        mkdir -p ${TMPDIR}

        cd ${TMPDIR}

        unzip ${FILE}

        cd -

        echo "user..."
        carton exec bin/librecat user add ${TMPDIR}/user.yml
        echo "publications..."
        carton exec bin/librecat publication add ${TMPDIR}/publications.yml
        echo "department..."
        carton exec bin/librecat department add ${TMPDIR}/department.yml
        echo "project..."
        carton exec bin/librecat project add ${TMPDIR}/project.yml
        echo "research_group..."
        carton exec bin/librecat research_group add ${TMPDIR}/research_group.yml

        rm -rf ${TMPDIR}

        echo "Done"
        ;;
    *)
        echo "usage: $0 {create|drop|drop_backup|drop_version|export|import}"
        exit 1
esac
