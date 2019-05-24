function trackdownload() {
    //TODO заменить хранимку gettrackbyouterguid на findbyparams
    try {

        var shadowtaskname = "trackdownload";
        var defaultDeviceId = settings.get("defaultDeviceId"); 
        var taskTable = "rdev___shadow_tasks";
        var pageNumber;

        
        var taskinfo = db.findbyparams(taskTable, { recname: shadowtaskname });
        if (taskinfo == null || taskinfo.length <= 0) return jsresult.error("В базе нет записи о фоновой задаче: " + shadowtaskname);

      //через фоновую задачу получаем номер страницы после предыдущего запуска фоновой задачи
        pageNumber = taskinfo[0].content;
        if (isNaN(parseInt(pageNumber, 10)) || pageNumber < 0) pageNumber = 0;
		//устанавливаем следующую страницу
        pageNumber++;
		//если дошли до 51 страницы до начинаем с первой опять
        if (pageNumber == 51) pageNumber = 1;

        var url = "http://zaycev.net/top/more.html?page=" + pageNumber;

        var body = null;


        var headers = {
            'Content-Type': "application/json"
        };


        var result = fetch(url, {
            method: "GET",
            headers: headers,
            body: body
        });

		//получаем html код страницы
        if (result == null || result.Data.length <= 0) return jsresult.error("Не удалось получить html страницы " + url);

        var html = result.Data;


		//ищем в html коде информацию по трэкам с помощью регулярных выражений
        var trackpattern = /musicset\/play\/\w{32}\/\d+.json/g;
        var tracklinks = html.match(trackpattern);
        if (tracklinks == null || tracklinks.length <= 0) return jsresult.error("Не удалось получить трэки из html кода страницы " + url);

        var artistpattern = /artist\/\d+.">.+?</g;
        var artists = html.match(artistpattern);
        if (artists == null || artists.length <= 0) return jsresult.error("Не удалось получить названия исполнителей из html кода страницы " + url);

        var titlepattern = /musicset-track__track-name.><a.+?</g;
        var titles = html.match(titlepattern);
        if (titles == null || titles.length <= 0) return jsresult.error("Не удалось получить названия трэков из html кода страницы " + url);

        var durationpattern = /musicset-track__duration.>.+?</g;
        var durations = html.match(durationpattern);
        if (durations == null || durations.length <= 0) return jsresult.error("Не удалось получить длительности трэков из html кода страницы " + url);


        var guid;
        var artist;
        var title;
        var duration;
        var dbresult;
        var params;
   
   //
        for (var i = 0; i < tracklinks.length; i++) {

            guid = tracklinks[i].substr(14, 32);
           
            params = {

                "name": "gettrackbyouterguid",
                "parameters": [
                    {
                        "name": "i_outerguid",
                        "value": guid,
                        "type": "SysGUID"
                    }
                ]
            };

            dbresult = db.execprocedure(params);
           
		   //если трэк с таким guid уже есть у нас в базе то пропускаем его
            if (dbresult != null && dbresult.length > 0) continue;

            url = "http://zaycev.net/" + tracklinks[i];
            artist = artists[i].substr(artists[i].indexOf('>') + 1, artists[i].indexOf('<') - artists[i].indexOf('>') - 1);
            title = titles[i].substring(titles[i].indexOf('><') + 2, titles[i].length);
            title = title.substr(title.indexOf('>') + 1, title.indexOf('<') - title.indexOf('>') - 1);
            duration = durations[i].substr(durations[i].indexOf('>') + 1, durations[i].indexOf('<') - durations[i].indexOf('>') - 1);
            duration = +duration.substr(0, 2) * 60 + +duration.substr(3, 2);

            //получаем прямую ссылку на файл
            result = sendRequest("GET", headers, url, null);
            var newurl = result.url;
           
            params = {
                "fields": {
                    "files": [{
                        "deviceid": defaultDeviceId,
                        "mediatype": "track",
                        "url": newurl,
                        "localdevicepathupload": url,
                        "name": title,
                        "artist": artist,
                        "recdescription": "trackFromJs",
                        "outerguid": guid,
                        "outersource": "Zaycev.net",
                        "length": duration
                    }]
                },
                "method": "uploadaudiofile"
            };

            body = JSON.stringify(params);
      
            url = String().concat(host, "/api/executejs");


            headers = {
                'Content-Type': "application/json",
                "Authorization": __TOKEN__
            };
// закачиваем трэк в базу через апи рдева
            result = fetch(url, {
                method: "POST",
                headers: headers,
                body: body
            });

           
        }
//передаем в базу номер текущей страницы с сайта
        return jsresult.success(pageNumber);
    }
    catch (ex) {

        throw new jsresult.error("Ошибка: " + ex.message);

    }


}


function trackmigrate() {

    var params = {
        name: "select_tracks_for_migration",
        parameters: {}
    };

    var tracks = db.execprocedure(params);

    if (tracks == null || tracks.length <= 0) return "no tracks for migration left";



    for (var i = 0; i < tracks.length; i++) {
        
        try {
            var fileinfo = {
                mediatype: "track",
                url: "http://api.ownradio.ru/v5/tracks/" + tracks[i].recid,
                name: tracks[i].recname == null ? "no value" : tracks[i].recname,
                recdescription: tracks[i].recdescription == null ? "" : tracks[i].recdescription
            };

            var uploadFileInfo = [{
                entityId: tracks[i].recid,
                entityName: tracks[i].recname == null ? "" : tracks[i].recname,
                columnName: "file",
                description: tracks[i].recdescription == null ? "" : tracks[i].recdescription,
                file: fileinfo
            }];

            file.upload(uploadFileInfo);
        }
        catch (e) {
            event.log("migration", null, e.message + " " + tracks[i].recid, 4, null);
            
        }
		finally{continue;};

    };
    return true;
}

function gettrackinfo() {

    var logObjectName = "gettrackinfobyid";
   

    var params = {
        name: "select_tracks_with_notittle",
        parameters: {}
    };

    var tracks = db.execprocedure(params);

    if (tracks == null || tracks.length <= 0) 
        return "no tracks left";

//event.log(logObjectName, null, "Confirming id:" + reqId + ", URL:" + confirmUrl + ", body:" + body, 1, reqId);
    event.log(logObjectName, null, "Получен трек с id " + tracks[0].recid, "1", 1, "2")


    // for (var i = 0; i < tracks.length; i++) {
    //     try {
    //         var trackinfo = gettrackinfobyid({ recid: tracks[i].recid });

    //         var track = {
    //             recid: tracks[i].recid,
    //             recname: trackinfo.title,
    //             artist: trackinfo.artist
    //         }

    //         db.update("tracks", track);
    //     }
    //     catch (e) {
    //         continue;
    //     }
    // }
 

    return true;
}

function gettrackinfobyid(params) {

    // return SMEVGATEWAY_URL;
    var logObjectName = "gettrackinfobyid";
 
        ///// костыль , db.findbyparams не работает/////////
    var url = String().concat(host, "/odata/rdev___sysfiles?$filter=(entityid eq " + params.recid +")&$select=recid,entityid");
    var track = sendRequest("GET", null, url, null);
    
        /////------///////////

    if (track == null || track.value.length<=0) 
        return "No track found";
    var recid = track.value[0].recid;

   // var url = host + "/file/download/" + recid; prod
    
    var url = "http://rdev.ownradio.ru" + "/file/download/" + "ffc8da4a-f30c-4c3e-ae52-4642ddd73d93";

    var file = {
        "url": url,
        "name": "fileName.mp3",
        "description":"desc"
        };

    var uploadFileInfo = [{
        entityId: params.recid,
        entityName: "tracks",
        columnName: "file",
        description: "desc2",
        file: file
    }];

    var apiaudiourl = settings.get("apiaudiourl");
    var url = String().concat(apiaudiourl,"/api/audio");
       

    var headers = {
        "Content-Type": "multipart/form-data"
    };
    var body = JSON.stringify(uploadFileInfo);
    var result = sendRequest("POST", headers, url, body);

    return result;
}

/**
 * Объект - отражающий результат выполнения фоновых задач
 */
var jsresult = {
	/**
	 * Функция возвращающая успешный результат из фоновых задач
	 * @param {*} data - данные которые необходимо вернуть из js
	 */
    success: function (data) {
        return {
            success: true,
            message: "",
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



