function parsezaycev() {
    try {

        var shadowtaskname = "parsezaycev";
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
        if (pageNumber >= 51) pageNumber = 1;

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
        event.log(shadowtaskname, null, "tracklinks.length = " + tracklinks.length + ", " + "artists.length = " + artists.length + ", " + "titles.length = " + titles.length + ", " + "durations.length = " + durations.length, 2, shadowtaskname);

        // if(tracklinks.length == artists.length && tracklinks.length == titles.length && tracklinks.length == durations.length){
        for (var i = 0; i < tracklinks.length; i++) {
            key = tracklinks[i].substr(14, 32);
            var trackFromDb = db.findbyparams("tracks", {outeruniquekey: key});
            if(trackFromDb == null){
                //Если не найдена запись в таблице "tracks", создаем новую запись
                var trackUrl = "http://zaycev.net/" + tracklinks[i];
                artist = artists[i].substr(artists[i].indexOf('>') + 1, artists[i].indexOf('<') - artists[i].indexOf('>') - 1);
                title = titles[i].substring(titles[i].indexOf('><') + 2, titles[i].length);
                title = title.substr(title.indexOf('>') + 1, title.indexOf('<') - title.indexOf('>') - 1);
                duration = durations[i].substr(durations[i].indexOf('>') + 1, durations[i].indexOf('<') - durations[i].indexOf('>') - 1);
                duration = +duration.substr(0, 2) * 60 + +duration.substr(3, 2);


                result = sendRequest("GET", headers, trackUrl, null);
                if(result != null){
                    var newurl = result.url;
                    params = {
                        "fields": {
                            "files": [{
                                "deviceid": defaultDeviceId,
                                "mediatype": "track",
                                "url": newurl,
                                "localdevicepathupload": trackUrl,
                                "name": title,
                                "artist": artist,
                                "recdescription": "trackFromJs",
                                "outerguid": key,
                                "outersource": "Zaycev.net",
                                "length": duration,
                                "outeruniquekey": key
                            }]
                        },
                        "method": "uploadaudiofile"
                    };

                    body = JSON.stringify(params);

                    rdevUrl = String().concat(host, "/api/executejs");


                    headers = {
                        'Content-Type': "application/json",
                        "Authorization": __TOKEN__
                    };
            // закачиваем трэк в базу через апи рдева
                    result = fetch(rdevUrl, {
                        method: "POST",
                        headers: headers,
                        body: body
                    });

                    if(result.success){
                        event.log(shadowtaskname, null, "Трек успешно загружен, ключ трека: " + key + " #" + i + " страница: " + pageNumber, 1, shadowtaskname);
                    }else{
                        event.log(shadowtaskname, null, "Трек не загружен, ключ трека: " + key + " #" + i + " страница: " + pageNumber, 4, shadowtaskname);
                    }
                }else{
                    event.log(shadowtaskname, null, "Ошибка, информация о треке не получена " + " #" + i + " страница: " + pageNumber, 96, shadowtaskname);
                }
            }
            else{
                event.log(shadowtaskname, null, "Ошибка, трек существует, ключ трека: " + key + " #" + i + " страница: " + pageNumber, 3, shadowtaskname);
                continue;
            }
        }
        db.update(taskTable, {
            recid: taskinfo[0].recid,
            content: pageNumber++
        });
    // }else{
    //     return jsresult.error("Ошибка: не равная длинна полученных данных");
    // }
        
}catch(ex){
        throw new jsresult.error("Ошибка: " + ex.message);
}
}

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