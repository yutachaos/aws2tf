#!/bin/bash
bus="default"
if [[ "$1" != "" ]]; then
    if [[ "$1" == *"|"* ]]; then
        bus=$(echo $1 | cut -f1 -d '|')
        ru=$(echo $1 | cut -f2 -d '|')      
        cmd[0]="$AWS events list-targets-by-rule --rule $ru --event-bus-name $bus" 
    else
        echo "invalid format should be bus|rulename exiting .."
        exit
    fi
else
    echo "must pass bus|rulename as parameter exiting .."
    exit
fi

pref[0]="Targets"
tft[0]="aws_cloudwatch_event_target"
idfilt[0]="Id"


#rm -f ${tft[0]}.tf

for c in `seq 0 0`; do
    
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "$cm : You don't have access for this resource"
        exit
    fi

    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            cname=`echo $awsout | jq -r ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}"`

            echo "$ttft $bus $ru $cname"

            fn=`printf "%s__%s__%s__%s.tf" $ttft $bus $ru $cname`


            printf "resource \"%s\" \"%s__%s__%s\" {" $ttft $bus $ru $cname > $fn
            printf "}" >> $fn
            if [[ "$bus" == "default" ]];then
                terraform import $ttft.${bus}__${ru}__${cname} "${ru}/${cname}" | grep Import
            else
                terraform import $ttft.${bus}__${ru}__${cname} "${bus}/${ru}/${cname}" | grep Import
            fi
            
            terraform state show $ttft.${bus}__${ru}__${cname} > t2.txt

            #echo $awsj | jq . 
            rm -f $fn
            cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt
            #	for k in `cat t1.txt`; do
            #		echo $k
            #	done
            file="t1.txt"
            echo $aws2tfmess > $fn
            lfn=""
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"` 
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == "arn" ]];then 
                        tt2=$(echo $tt2 | tr -d '"')
                        if [[ "$tt2" == *":lambda:"* ]]; then
                            lfn=$(echo $tt2 | rev | cut -f1 -d':' | rev)
                            t1=`printf "%s = aws_lambda_function.%s.arn" $tt1 $lfn`
                        fi                 
                    fi     

                    if [[ ${tt1} == "id" ]];then skip=1; fi          
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi

                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"

            if [[ "$lfn" != "" ]];then
                ../../scripts/700-get-lambda-function.sh $lfn
            fi

            
        done
    fi 
done

#rm -f t*.txt
