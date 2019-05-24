/**
 * Фоновая задача по обновлению инфы о треках с некорректной инфой(пустой или null)
 */
function updatetrackinfo(){
    var logObjectName = "updatetrackinfo";
    
    var radioRdevUrl = "http://rdev.ownradio.ru/"; 

    var params = {
        name: "select_tracks_with_notittle",
        parameters: {}
    };

    var tracks = db.execprocedure(params);

    if (tracks == null || tracks.length <= 0) {
        return jsresult.success("", "Не найдено некорректных треков");
    }else{
        event.log(logObjectName, null, "Хранимка select_tracks_with_notittle вызвана", 1, "select_tracks_with_notittle");
    }

    if(tracks[0].recid != null){
        event.log(logObjectName, null, "id полученного трека не пустое", 1, "tracks[0].recid");
        //Получение инфы о треке из БД
        event.log(logObjectName, null, "Получен трек с id " + tracks[0].recid, "gettrackinfobyid", 1, "2");

        var procparams = {
                    name: "get_sysfiles_entity",
                    parameters: [
                        {
                            name: "trackid",
                            type: "SysString",
                            value: tracks[0].recid
                        }
                    ]
                 };


        var sysfilesentity = db.execprocedure(procparams);
        if(sysfilesentity[0] != null){
            event.log(logObjectName, null, "entityid " + sysfilesentity[0].sysfileid, "updatetrackinfo", 1, "2");
                
            var rdevFileUrl = radioRdevUrl + "file/download/" + sysfilesentity[0].sysfileid
            // var rdevFileUrl = radioRdevUrl + "file/download/" + "890ee159-6674-4d38-b898-24f4d0d1c106"

            var file = {
                "url": rdevFileUrl,
                "name": sysfilesentity[0].sysfileid + ".mp3",
                "description":"desc"
            };

            var uploadFileInfo = [{
                entityId: sysfilesentity[0].sysfileid,
                entityName: "tracks",
                columnName: "file",
                description: "desc2",
                file: file
            }];

            // var apiUrl = "http://10.10.10.18:5002/api/audio";
            var apiaudiourl = settings.get("apiaudiourl");
            var apiUrl = String().concat(apiaudiourl,"/api/audio");
            var headers = {
                "Content-Type": "multipart/form-data"
            };

            var result = fetch(apiUrl, {
                method: "POST",
                headers: headers,
                body: JSON.stringify(uploadFileInfo)
            });
            var resultSuccess = JSON.parse(result.Success);
            if(resultSuccess){
                var resultObject = JSON.parse(result.Data)
                if(resultObject.title == null && resultObject.artist == null){
                    db.update("tracks",{
                        recid: tracks[0].recid,
                        recname: "Title",
                        artist: "Artist",
                        isfilledinfo: true
                    });
                    return jsresult.error("Трек не распознан, id: " + tracks[0].recid);
                }else{
                    db.update("tracks",{
                        recid: tracks[0].recid,
                        recname: resultObject.title,
                        artist: resultObject.artist,
                        isfilledinfo: true
                    });
                    return jsresult.success("", "Запись c id " + tracks[0].recid + " обновлена, трек " + resultObject.artist + " - " + resultObject.title); 
                }
            }else{
                return jsresult.error("Дневной лимит исчерпан");
            }
        }else{
            return jsresult.error("Хранимка get_sysfiles_entity вернула null");
        }
    }else{
        return jsresult.error("Хранимка select_tracks_with_notittle вернула трек с id == null");
    }

}

/**
 * Объект - отражающий результат выполнения фоновых задач
 */
var jsresult = {
    /**
     * Функция возвращающая успешный результат из фоновых задач
     * @param {*} data - данные которые необходимо вернуть из js
     */
    success: function (data, message) {
        return {
            success: true,
            message: message,
            data: data
        };
    },
    /**
     * Функция возвращающая результат с ошибкой из фоновых задач
     * @param {*} message - текст сообщения об ошибки
     */
    error: function (message) {
        return {
            success: false,
            message: message,
            data: null
        };
    }
};