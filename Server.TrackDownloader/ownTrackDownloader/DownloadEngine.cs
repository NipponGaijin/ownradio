using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace ownTrackDownloader
{
    public class DownloadEngine
    {
        public async void Start(ILogger logger)
        {
            GlobalSettings.ReadFromJson();

            PageGetter pageGetter = new PageGetter(logger);
            TracksGetter tracksGetter = new TracksGetter(logger);
            TracksChecker tracksChecker = new TracksChecker();
            TrackUploader trackUploader = new TrackUploader(logger);

            try
            {
                do
                {

                    //получаем контент страницы с нужного раздела
                    logger.LogInformation("Обработка страницы с Zaycev.net");
                    var pageContent = await pageGetter.NextPage(ZaycevRubric.top);

                    //вычленяем из ответа трэки
                    logger.LogInformation("Вычленяем из html ответа трэки");
                    List<Track> tracks = tracksGetter.GetTracks(pageContent.ToString());

                    //удаляем из списка те трэки которые у нас уже есть
                    logger.LogInformation("Удаляем из списка те трэки которые у нас уже есть");
                    tracks = tracksChecker.CheckForNew(tracks);

                    if (tracks.Count > 0)
                    {
                        logger.LogInformation("Обработка трэков со страницы - скачиваем, генерим uuid, сохраняем на сервере, пишем в бд");
                        foreach (Track track in tracks)
                        {

                            // скачиваем сам файл
                            var audio = await tracksGetter.GetTrack(track.Url).ConfigureAwait(false);

                            //генерим UUID для базы ownRadio
                            track.Recid = trackUploader.Generate_UUID();

                            //закачиваем на сервак
                            trackUploader.SaveOnDisk(audio, track);

                            //вносим запись в бд таблицу tracks
                            trackUploader.BDTrackInsert(track);
                        }
                    }
                } while (true);
            }
            catch (Exception ex)
            {
                logger.LogInformation("Ошибка: "+ ex.Message);
            }
        }

        
    }
}
