#!/bin/sh
#
# Copyright 2020 IBM Corporation

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http:#www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
{{ template "elk.settings.all.prepare" . -}}
set -uo pipefail

echo "`date` - 1. preparing to check .kibana index migration"
# Prepare es client api url
{{- if .Values.elasticsearch.security.authc.enabled }}
# Use https protcol if security enabled
protocol=https
export CERT_DIR=/usr/share/elasticsearch/config/tls
{{ else }}
# Use http protcol if security disabled
protocol=http
{{- end }}

endpoint={{ .Values.elasticsearch.name }}
port={{ .Values.elasticsearch.client.restPort }}
url="$protocol://$endpoint:$port"

# Check if the .kibana index migration is done
# Check and wait until elasticsearch is up and sends back good json response
while true
do
    echo "`date` - 2. checking if Elasticsearch is up"
    temp_file=$(mktemp)
    set -x
    http_code=$(curl -o $temp_file -w '%{http_code}' -E $CERT_DIR/curator.crt --key $CERT_DIR/curator.key --cacert $CERT_DIR/ca.crt $url)
    set +x

    resp=$(cat ${temp_file})
    rm ${temp_file}

    echo "http_code=$http_code, resp=$resp"

    if [ "$http_code" != "200" ]; then
        echo "Elasticsearch is not up yet... sleep 10s"
        sleep 10
        continue
    fi

    echo "`date` - 3. looking for current .kibana index version"
    temp_file=$(mktemp)
    set -x
    http_code=$(curl -o $temp_file -w '%{http_code}' -E $CERT_DIR/curator.crt --key $CERT_DIR/curator.key --cacert $CERT_DIR/ca.crt $url/.kibana/_settings)
    set +x

    resp=$(cat ${temp_file})
    rm ${temp_file}

    echo "http_code=$http_code, resp=$resp"

    case $http_code in
    "404")
        echo "no .kibana index found. use this as an indicator of a fresh install"
        echo "no need to wait for migration"
        break
        ;;
    "200")
        echo "got 200 http status code, checking response json..."
        echo "`date` - 4. identifying kibana version"
        created_by=$(echo $resp| jq -r 'first(.[]).settings.index.version.created')

        if [[ -z "$created_by" ]]; then
            echo "no .kibana index found. use this as an indicator of a fresh install"
            created_by='6081099'
        fi

        echo "$created_by=$created_by"

        major_version="${created_by:0:1}"
        echo "major_version=$major_version"

        if [ "6" = "$major_version" ]; then
            echo "index version up-to-date. no need to migrate"
            break
        else
            echo "`date` - 5. migrating .kibana index from version $created_by..."

            # prepare the json
            json1='{
                "index.blocks.write": true
            }'
            json2='{
                "settings" : {
                    "number_of_shards" : 1,
                    "index.mapper.dynamic": false
                },
                "mappings" : {
                    "doc": {
                    "properties": {
                        "type": {
                        "type": "keyword"
                        },
                        "updated_at": {
                        "type": "date"
                        },
                        "config": {
                        "properties": {
                            "buildNum": {
                            "type": "keyword"
                            }
                        }
                        },
                        "index-pattern": {
                        "properties": {
                            "fieldFormatMap": {
                            "type": "text"
                            },
                            "fields": {
                            "type": "text"
                            },
                            "intervalName": {
                            "type": "keyword"
                            },
                            "notExpandable": {
                            "type": "boolean"
                            },
                            "sourceFilters": {
                            "type": "text"
                            },
                            "timeFieldName": {
                            "type": "keyword"
                            },
                            "title": {
                            "type": "text"
                            }
                        }
                        },
                        "visualization": {
                        "properties": {
                            "description": {
                            "type": "text"
                            },
                            "kibanaSavedObjectMeta": {
                            "properties": {
                                "searchSourceJSON": {
                                "type": "text"
                                }
                            }
                            },
                            "savedSearchId": {
                            "type": "keyword"
                            },
                            "title": {
                            "type": "text"
                            },
                            "uiStateJSON": {
                            "type": "text"
                            },
                            "version": {
                            "type": "integer"
                            },
                            "visState": {
                            "type": "text"
                            }
                        }
                        },
                        "search": {
                        "properties": {
                            "columns": {
                            "type": "keyword"
                            },
                            "description": {
                            "type": "text"
                            },
                            "hits": {
                            "type": "integer"
                            },
                            "kibanaSavedObjectMeta": {
                            "properties": {
                                "searchSourceJSON": {
                                "type": "text"
                                }
                            }
                            },
                            "sort": {
                            "type": "keyword"
                            },
                            "title": {
                            "type": "text"
                            },
                            "version": {
                            "type": "integer"
                            }
                        }
                        },
                        "dashboard": {
                        "properties": {
                            "description": {
                            "type": "text"
                            },
                            "hits": {
                            "type": "integer"
                            },
                            "kibanaSavedObjectMeta": {
                            "properties": {
                                "searchSourceJSON": {
                                "type": "text"
                                }
                            }
                            },
                            "optionsJSON": {
                            "type": "text"
                            },
                            "panelsJSON": {
                            "type": "text"
                            },
                            "refreshInterval": {
                            "properties": {
                                "display": {
                                "type": "keyword"
                                },
                                "pause": {
                                "type": "boolean"
                                },
                                "section": {
                                "type": "integer"
                                },
                                "value": {
                                "type": "integer"
                                }
                            }
                            },
                            "timeFrom": {
                            "type": "keyword"
                            },
                            "timeRestore": {
                            "type": "boolean"
                            },
                            "timeTo": {
                            "type": "keyword"
                            },
                            "title": {
                            "type": "text"
                            },
                            "uiStateJSON": {
                            "type": "text"
                            },
                            "version": {
                            "type": "integer"
                            }
                        }
                        },
                        "url": {
                        "properties": {
                            "accessCount": {
                            "type": "long"
                            },
                            "accessDate": {
                            "type": "date"
                            },
                            "createDate": {
                            "type": "date"
                            },
                            "url": {
                            "type": "text",
                            "fields": {
                                "keyword": {
                                "type": "keyword",
                                "ignore_above": 2048
                                }
                            }
                            }
                        }
                        },
                        "server": {
                        "properties": {
                            "uuid": {
                            "type": "keyword"
                            }
                        }
                        },
                        "timelion-sheet": {
                        "properties": {
                            "description": {
                            "type": "text"
                            },
                            "hits": {
                            "type": "integer"
                            },
                            "kibanaSavedObjectMeta": {
                            "properties": {
                                "searchSourceJSON": {
                                "type": "text"
                                }
                            }
                            },
                            "timelion_chart_height": {
                            "type": "integer"
                            },
                            "timelion_columns": {
                            "type": "integer"
                            },
                            "timelion_interval": {
                            "type": "keyword"
                            },
                            "timelion_other_interval": {
                            "type": "keyword"
                            },
                            "timelion_rows": {
                            "type": "integer"
                            },
                            "timelion_sheet": {
                            "type": "text"
                            },
                            "title": {
                            "type": "text"
                            },
                            "version": {
                            "type": "integer"
                            }
                        }
                        },
                        "graph-workspace": {
                        "properties": {
                            "description": {
                            "type": "text"
                            },
                            "kibanaSavedObjectMeta": {
                            "properties": {
                                "searchSourceJSON": {
                                "type": "text"
                                }
                            }
                            },
                            "numLinks": {
                            "type": "integer"
                            },
                            "numVertices": {
                            "type": "integer"
                            },
                            "title": {
                            "type": "text"
                            },
                            "version": {
                            "type": "integer"
                            },
                            "wsState": {
                            "type": "text"
                            }
                        }
                        }
                    }
                    }
                }
            }'
            json3='{
                "source": {
                    "index": ".kibana"
                },
                "dest": {
                    "index": ".kibana-6"
                },
                "script": {
                    "inline": "ctx._source = [ ctx._type : ctx._source ]; ctx._source.type = ctx._type; ctx._id = ctx._type + \":\" + ctx._id; ctx._type = \"doc\"; ",
                    "lang": "painless"
                }
            }'
            json4='{
                "actions" : [
                    { "add":  { "index": ".kibana-6", "alias": ".kibana" } },
                    { "remove_index": { "index": ".kibana" } }
                ]
            }'

            echo "calling Elasticsearch API .kibana index ..."
            set -x
            {{- if .Values.elasticsearch.security.authc.enabled }}
            curl -s -E $CERT_DIR/curator.crt --key $CERT_DIR/curator.key --cacert $CERT_DIR/ca.crt  -X PUT "$url/.kibana/_settings" -H 'Content-Type: application/json' -d"${json1}"
            curl -s -E $CERT_DIR/curator.crt --key $CERT_DIR/curator.key --cacert $CERT_DIR/ca.crt -X PUT "$url/.kibana-6" -H 'Content-Type: application/json' -d"${json2}"
            curl -s -E $CERT_DIR/curator.crt --key $CERT_DIR/curator.key --cacert $CERT_DIR/ca.crt -X POST "$url/_reindex" -H 'Content-Type: application/json' -d"${json3}"
            curl -s -E $CERT_DIR/curator.crt --key $CERT_DIR/curator.key --cacert $CERT_DIR/ca.crt  -X POST "$url/_aliases" -H 'Content-Type: application/json' -d"${json4}"
            {{ else }}
            curl -s -X PUT "$url/.kibana/_settings" -H 'Content-Type: application/json' -d"${json1}"
            curl -s -X PUT "$url/.kibana-6" -H 'Content-Type: application/json' -d"${json2}"
            curl -s -X POST "$url/_reindex" -H 'Content-Type: application/json' -d"${json3}"
            curl -s -X POST "$url/_aliases" -H 'Content-Type: application/json' -d"${json4}"
            {{- end }}
            set +x
        fi
        ;;
    *)
        echo "got bad http response code $http_code. retrying in 10s..."
        sleep 10
        ;;
    esac
done

echo "`date` - 6. Migration is DONE!"
