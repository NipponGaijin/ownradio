function regnewdevice(params) {
    var device = db.findbyrecid("devices", params.recid);

    if (device != null)
        return "Устройство уже зарегистрировано.";

    if (params.recname == null)
        params.recname = "New unknown device";

    var userInfo = db.findbyrecid("users", params.recid);
    var user = null;

    if (userInfo == null) {
        user = { 
            recid: params.recid, 
            reccreated: new Date(),
            recname: params.recname
        };

        db.insert("users", user);

    } else {
        user = { 
            recid: userInfo.recid, 
            reccreated: new Date(),
            recname: params.recname
        }

        db.update("users", user);
    }

    params.userid = user.recid;
    
    var dresult = db.insert("devices", params);

    return dresult;
}

function showdeviceinfo(params) {
    return db.findbyrecid("devices", params.recid);
}

function savehistory(params) {

    var track = db.findbyrecid("tracks", params.trackid);
    var device = db.findbyrecid("devices", params.deviceid);

    if(track == null){
        return "Не найдена запись о трэке.";
    }

    if (device == null) {
        return "Не найдена запись об устройстве.";
    }

    var history = db.findbyrecid("histories", params.recid);
    var recid = {};

    if (history != null) {
        var count = history.countsend;
        db.update("histories", { recid: history.recid, countsend: count == null ? 0 : ++count });
        recid = {id: history.recid};
    } else {
        history = {
            recid: params.recid,
            trackid: params.trackid,
            deviceid: params.deviceid,
            countsend: 1,
            islisten: params.islisten,
            lastlisten: params.lastlisten,
            userid: params.userid
        }

        recid = db.insert("histories", history);
    

    var rating = db.findbyparams("ratings", { userid: params.userid, trackid: params.trackid });
    var dbresult = null;

    if (rating != null) {
        dbresult = db.update("ratings", { recid: rating[0].recid, lastlisten: params.lastlisten, ratingsum: Number(rating[0].ratingsum) + Number(params.islisten) });
    } else {
        dbresult = db.insert("ratings", {
            userid: params.userid,
            trackid: params.trackid,
            lastlisten: params.lastlisten,
            ratingsum: params.islisten
        });
    }
    }
    
     var procedureparams =
    {
        "name": "updateratios",
        "parameters": [{ "name": "i_userid", "value": params.userid, "type":"SysGUID" }]
    };

    db.execprocedure(procedureparams);
    
    return recid;
}

function showhistoryinfo(params) {
    return db.findbyrecid("histories", params.recid);
}


/**
 * Функция получения следующей главы аудиокниги 
 * @param {Guid} deviceid - Идентификатор устройства пользователя
 * @param {Guid} bookid - Идентификатор книги
 * @param {int} chapter - Номер главы
 */
function nextchapter(params) {
         
        var procedureparams =
        {
            "name": "getnextchapter",
            "parameters": [{ "name": "i_deviceid", "value": params.deviceid, "type": "SysGUID" },
                { "name": "i_bookid", "value": params.bookid, "type": "SysGUID" },
                { "name": "i_chapter", "value": params.chapter, "type": "SysInt" }]
        };

        return db.execprocedure(procedureparams);

}

function nexttrackbyratio(params){
        var procedureparams =
    {
        "name": "getnexttrackbyratio",
        "parameters": [{ "name": "i_deviceid", "value": params.deviceid, "type":"SysGUID" },{ "name": "i_ratio", "value": params.ratio, "type":"SysInt" }]
    };

    return db.execprocedure(procedureparams);
}

function showtrackinfo(params) {
    return db.findbyrecid("tracks", params.recid);
}

function showtrackinfobydevice(params) {
    return db.findbyparams("tracks", params);
}

function gettrack(params) {
  //чтобы файл вернулся потоком надо при вызове передать сюда "resulttype":"filestream"
    //TODO заменить коствль на db.findbyparams

    ///// костыль ///////// db.findbyparams не работает с guid и в частности здесь возвращает из таблицы поле типа bytea а оно вызывает ошибку в методе fetch при приведении
    var url = String().concat(host, "/odata/rdev___sysfiles?$filter=(entityid eq " + params.recid + ")&$select=recid,entityid");
    var track = sendRequest("GET", null, url, null);
    /////------///////////
    
    if (track == null || track.value.length<=0) return "No track found in files table";

    var recid = track.value[0].recid;

    var url = host + "/file/download/" + recid;

    // добавляем "Response-Type": "audio/mpeg" чтобы результат не возвращался в виде текста а читался потоком
    var headers = {
        'Content-Type': "application/json",
        "Response-Type": "audio/mpeg"
    };

    var result = fetch(url, {
        method: "GET",
        headers: headers,
        body: null
    });

    return result;
}

function uploadaudiofile(params) {

    event.log("uploadaudiofile", null, "Запущен метод uploadaudiofile.", 2);

    var uploadFileInfo = [];
    var errors = [];

    params = toLowerCaseKeys(params);

    // Необходимо все keys каждого принятого файла перевести в нижний регистр
    for (var i = 0; i < params.files.length; i++) {
        params.files[i] = toLowerCaseKeys(params.files[i]);
    }

    if(params.files.length <= 0){
        throw new Error("Не удалось получить информацию о файлах в запросе.");
    }

    event.log("uploadaudiofile", null, "Запускаем цикл на обработку файлов.", 2);

    // Обходим файлы из запроса заполняя список файлов для сохранения в таблицу Rdev-a
    params.files.forEach(function(file) {

        var trackId = null;

        // Если полученный файл является файлом аудиокниги
        if(file.mediatype == "audiobook") {

            // Проверим наличие обязательных полей у файла
            if (file.chapter == undefined || file.localdevicepathupload == undefined) {
                event.log("uploadaudiofile", null, "Ошибка обработки параметров файла: " + file.name + ". Убедитесь что в запросе указаны свойства localdevicepathupload и chapter.", 4);
                errors.push("Ошибка обработки параметров файла: " + file.name + ". Убедитесь что в запросе указаны свойства localdevicepathupload и chapter.");
                return;
            }

            event.log("uploadaudiofile", null, "Пытаемся получить из БД информацию по файлу.", 2);

            // Пытаемся получить из БД информацию по файлу
            var checkFile = db.findbyparams("tracks", { chapter: file.chapter, localdevicepathupload: file.localdevicepathupload });
            
            // Если файл есть информация по файлу, переходим к следующей итерации
            if(checkFile != null) {
                event.log("uploadaudiofile", null, "В таблице tracks уже имеется информация о треке " + file.localdevicepathupload + 
                " который является " + file.chapter + " главой книги." , 3);

                event.log("uploadaudiobook", null, "checkFile: " + checkFile, 3);
                return;
            }

            event.log("uploadaudiofile", null, "Информации в бд нет, добавляем информацию из описания файла.", 2);

            // Формируем объект для сохранения информации по файла
            var insertInfo = {
                recdescription: file.recdescription,
                reccreated: new Date(),
                deviceid: file.deviceid,
                uploaduserid: file.deviceid,
                mediatype: file.mediatype,
                chapter: file.chapter,
                recname: file.name,
                ownerrecid: file.ownerrecid,
                localdevicepathupload: file.localdevicepathupload,
                iscensorial: true,
                iscorrect: true,
                size: file.size
            };
            
            event.log("uploadaudiofile", null, "Добавляем информацию по файлу в таблицу tracks.", 2);

            // Добавляем информацию по файлу в таблицу tracks
            trackId = db.insert("tracks", insertInfo);

        } else if(file.mediatype == "track") {

            if (file.localdevicepathupload == undefined) {
                errors.push("Ошибка обработки параметра файла: " + file.name + ". Убедитесь что в запросе указано свойство localdevicepathupload.");
                return;
            }

            var checkFile = db.findbyparams("tracks", { localdevicepathupload: file.localdevicepathupload });
            
            if(checkFile != null) return;

            var insertInfo = {
                deviceid: file.deviceid,
                uploaduserid: file.deviceid,
                mediatype: file.mediatype,
                recname: file.name,
                localdevicepathuploadurn: params.localdevicepathupload,
                outerguid: file.outerguid,
                outersource: file.outersource,
                localdevicepathupload: file.localdevicepathupload,
                artist: file.artist,
                length: file.length,
                outeruniquekey: file.outeruniquekey
            };

            trackId = db.insert("tracks", insertInfo);

        } else {
            errors.push("Файл имеет недопустимый медиатип: " + file.mediatype);
            return;
        }

        // Если при добавлении информации по файлу возникла ошибка, запишем ее в список ошибок
        if(trackId == null) {
            errors.push("Не удалось получить идентификатор для файла: " + file.name);
            return;
        }

        event.log("uploadaudiofile", null, "Информация по треку получена, добавляем в коллекцию.", 2);
        event.log("uploadaudiofile", null, "Идентификатор записи: " + trackId.id, 2);

        // добавляем файл в коллекцию файлов загружаемых на Rdev
        uploadFileInfo.push({
            entityId: trackId.id,
            entityName: "tracks",
            columnName: "file",
            description: file.recdescription,
            file: file
        });
    });

    // Если в результате обхода по файлам возникли ошибки выходим из метода
    if(errors.length > 0)
        throw new Error(String().concat(errors));

    // Если список файлов для Rdev не пустой запустим upload файлов
    if(uploadFileInfo.length > 0)
        return file.upload(uploadFileInfo);

    throw new Error("Не удалось найти файлы в запросе.");
}

function downloadaudiobook(params) {

    var downloadHistories = db.findbyparams("downloadhistory", { url: params.urn, mediatype: "audiobook" });
    var downloadHistory = null;

    // Проверяем информацию из БД, если книга загружается менее 5-мин выходим из функции, если книга загружена выходим из функции
    if (downloadHistories != null) {

        downloadHistory = downloadHistories[0];

        // Если аудиокнига не была полностью скачена
        if (downloadHistory.isfull != 1) {

            // Если книга в процессе загрузки
            if (downloadHistory.inprocessing == 1) {

                let currentDate = new Date();
                let createDate = new Date(downloadHistory.reccreated);

                let delta = createDate - currentDate;

                let deltaDay = Math.abs(Math.round(delta / 1000 / 60 / 60 / 24));
                let deltaHours = Math.abs(currentDate.getUTCHours() - createDate.getHours());
                let deltaMinutes = Math.abs(currentDate.getUTCMinutes() - createDate.getMinutes());

                if (deltaDay == 0 && deltaHours == 0 && deltaMinutes <= 10) {
                    return "Аудиокнига " + params.recname + "загружается менее 10 минут, выходим из метода"; // Книга загружается менее 10 мин, выходим
                } else {
                    // Книга загружается слишком долго стоит повторить попытку
                    db.update("downloadhistory", {
                        recid: downloadHistory.recid,
                        reccreated: new Date(),
                        isfull: 0,
                        inprocessing: 1
                    });
                }
            }
        } else {
            return "Аудиокнига " + params.recname + " уже загружена.";
        }
    }
    else {
        //В БД нет информации по книге, добавляем и приступаем к загрузке
        db.insert("downloadhistory", {
            recname: params.recname,
            reccreated: new Date(),
            urn: params.urn,
            mediatype: "audiobook",
            isfull: 0,
            inprocessing: 1
        });
    }

    //Загружаем архив с аудиокнигой
    var path = file.download(params.downloadurl);

    // Если это была первая загрузка
    if (downloadHistory == null) {
        var listDownloadHistory = db.findbyparams("downloadhistory", { url: params.urn });

        if (listDownloadHistory != null) {
            downloadHistory = listDownloadHistory[0];
        }
    }

    db.update("downloadhistory", {
        recid: downloadHistory.recid,
        recupdated: new Date(),
        isfull: 1,
        inprocessing: 0,
        path: path
    });

    var files = file.unpack(path);

    if (files.count == 0) {
        return "Не удалось получить список файлов из архива.";
    }

    var ownerrecid = null;
    var chapter = 0;

    files.forEach(function (fileMp3) {

        if (fileMp3.FileName.split('.').pop() != "mp3") {
            return;
        }

        chapter++;

        if (chapter == 1) {
            ownerrecid = file.LocalFileName;
        }

        var tableParams = {
            recid: fileMp3.LocalFileName,
            deviceid: params.deviceid,
            uploaduserid: params.deviceid,
            recname: fileMp3.FileName,
            reccreated: new Date(),
            recdescription: params.recname,
            mediatype: "audiobook",
            path: fileMp3.Path,
            chapter: chapter,
            ownerrecid: ownerrecid,
            urn: params.urn
        };

        return db.insert("tracks", tableParams);
    });
}

function downloadtrack(params) { 

    var downloadHistories = db.findbyparams("downloadhistory", { url: params.url, mediatype: "track" });
    var downloadHistory = null;

    if (downloadHistories != null) {

        downloadHistory = downloadHistories[0];

        // Если трэк не был полностью скачен
        if (downloadHistory.isfull != 1) {

            // Если трэк в процессе загрузки
            if (downloadHistory.inprocessing == 1) {

                let currentDate = new Date();
                let createDate = new Date(downloadHistory.reccreated);

                let delta = createDate - currentDate;

                let deltaDay = Math.abs(Math.round(delta / 1000 / 60 / 60 / 24));
                let deltaHours = Math.abs(currentDate.getUTCHours() - createDate.getHours());
                let deltaMinutes = Math.abs(currentDate.getUTCMinutes() - createDate.getMinutes());

                if (deltaDay == 0 && deltaHours == 0 && deltaMinutes <= 5) {
                    return "Mp3 файл " + params.recname + " загружается менее 5 минут."; // Mp3 файл загружается менее 5 мин, выходим
                } else {
                    // трэк загружается слишком долго стоит повторить попытку
                    db.update("downloadhistory", {
                        recid: downloadHistory.recid,
                        reccreated: new Date(),
                        isfull: 0,
                        inprocessing: 1,
                        mediatype: "track"
                    });
                }
            }
        } else {
            return "Mp3 файл " + params.recname + " уже загружен.";
        }
    }
    else {
        //В БД нет информации по трэку, добавляем и приступаем к загрузке
        db.insert("downloadhistory", {
            recname: params.recname,
            reccreated: new Date(),
            url: params.url,
            mediatype: "track",
            isfull: 0,
            inprocessing: 1
        });
    }

    var path = file.download(params.url);

    // Если это была первая загрузка
    if (downloadHistory == null) {
        var listDownloadHistory = file.findbyparams("downloadhistory", { url: params.url });

        if (listDownloadHistory != null) {
            downloadHistory = listDownloadHistory[0];
        }
    }

    db.update("downloadhistory", {
        recid: downloadHistory.recid,
        recupdated: new Date(),
        isfull: 1,
        inprocessing: 0,
        path: path
    });

    var tableParams = {
        recname: params.recname,
        deviceid: params.deviceid,
        reccreated: new Date(),
        recdescription: params.recname,
        mediatype: "track",
        path: path,
        state: 1
    };

    return db.insert("tracks", tableParams);
}
