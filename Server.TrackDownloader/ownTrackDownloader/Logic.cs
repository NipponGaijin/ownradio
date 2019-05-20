using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Npgsql;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Data;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace ownTrackDownloader
{
    public  class PageGetter
    {
        private int _currentPageNumber  = 0;
        private HttpClient _clientHttp = new HttpClient();
        private ILogger _logger;

        public PageGetter(ILogger logger)
        {
            _logger = logger;
        }

        public int CurrentPageNumber
        {
            get { return _currentPageNumber; }
            set {_currentPageNumber = value; }
        }

        public async Task<string> NextPage(ZaycevRubric rubric)
        {
            _currentPageNumber++;
            if (_currentPageNumber == 51) _currentPageNumber = 1;

            var url = $"http://zaycev.net/{rubric}/more.html?page={_currentPageNumber}";
            _logger.LogInformation("Обработка страницы с Zaycev.net: " + url);

            var response = await _clientHttp.GetAsync(url);

            var html = await response.Content.ReadAsStringAsync();

            

            return html;
        }
    }

    public class TracksGetter
    {
        private List<Track> _tracks = new List<Track>();
        private HttpClient _clientHttp = new HttpClient();
        private ILogger _logger;

        public TracksGetter(ILogger logger)
        {
            _logger = logger;
        }

        public List<Track> GetTracks(string pageContent)
        {
            int index = 0;
            const string pattern = @"(?<link>musicset/play/(?<guid>[\w]{32}?)/[\d]*.json?)";
            var regex = new Regex(pattern);
            var matches = regex.Matches(pageContent);

            var artists = Regex.Matches(pageContent, "\\/artist\\/\\d+\">(.+?)<\\/a>").Cast<Match>().Select(x => x.Groups[1].Value).ToList();
            var titles = Regex.Matches(pageContent, "musicset-track__track-name\"><a.+?>(.+?)<\\/a>").Cast<Match>().Select(x => x.Groups[1].Value).ToList();
            var durations = Regex.Matches(pageContent, "data-duration=\"(\\d+)").Cast<Match>().Select(x => x.Groups[1].Value).ToList();


            foreach (Match match in matches)
            {
                var link = match.Groups["link"].Value;
                var guid = Guid.Parse(match.Groups["guid"].Value);

                _tracks.Add(new Track
                {
                    Outerguid = guid,
                    Url = $"http://zaycev.net/{link}",
                    Artist = artists[index],
                    Recname = titles[index],
                    Length = int.Parse(durations[index]),
                    Outersource = "Zaycev.net",
                    Deviceid = Guid.Parse(GlobalSettings.defaultDeviceId)
                });

                index++;
            }

            return _tracks;
        }

        public async Task<byte[]> GetTrack(string url)
        {
            _logger.LogInformation("Скачиваем трэк с Zaycev.net: "+ url);
            using (var r = await _clientHttp.GetAsync(url).ConfigureAwait(false))
            {
                var responseString = await r.Content.ReadAsStringAsync().ConfigureAwait(false);
                var json = JsonConvert.DeserializeObject<dynamic>(responseString);
                string s = json.url;

                using (var r2 = await _clientHttp.GetAsync(s).ConfigureAwait(false))
                {
                    return await r2.Content.ReadAsByteArrayAsync().ConfigureAwait(false);
                }
            }
        }
    }

    public class TrackUploader
    {
        private HttpClient _clientHttp = new HttpClient();
        private ConfigurationBuilder conf = new ConfigurationBuilder();
        private ILogger _logger;

        public TrackUploader(ILogger logger)
        {
            _logger = logger;
        }

        public async Task<System.Net.HttpStatusCode> Upload(Track track, byte[] audio)
        {
            

            var form = new MultipartFormDataContent {
                { new StringContent(track.Recid.ToString()), "fileGuid" },
                { new StringContent(track.Url), "filePath" },
                { new StringContent(GlobalSettings.defaultDeviceId), "deviceId" },
                { new ByteArrayContent(audio, 0, audio.Count()), "musicFile", $"{track.Recid}.mp3" },
                { new StringContent(track.Recname), "title" },
                { new StringContent(track.Artist), "artist" },
                { new StringContent(track.Length.ToString()), "length " },
                { new StringContent( (audio.Count() / 1024).ToString() ), "size" },
            };

            // TODO: Replace link api, stringContent

            using (var response = await _clientHttp.PostAsync($"http://api.ownradio.ru/v6/tracks", form).ConfigureAwait(false))
            {
                return response.StatusCode;
            }
        }

        public void SaveOnDisk(byte[] audio, Track track)
        {
            string full_path;
            string path;

            path = GlobalSettings.mediaDirectory + track.Deviceid;
            //  full_path = GlobalSettings.mediaDirectory + track.Deviceid + "\\" + track.Recid + track.Recname + track.Artist + ".mp3"; //test

            full_path = Path.Combine(GlobalSettings.mediaDirectory, track.Deviceid.ToString(), track.Recid.ToString() + ".mp3"); //prod

           // full_path = GlobalSettings.mediaDirectory + track.Deviceid + "\\" + track.Recid + ".mp3"; //prod

            if (!Directory.Exists(path)) Directory.CreateDirectory(path);

            _logger.LogInformation("Сохраняем на диск: " + full_path);
            File.WriteAllBytes(full_path, audio);
        }

        public Guid Generate_UUID()
        {
            Guid newGuid;

            using (NpgsqlConnection conn = new NpgsqlConnection(GlobalSettings.connectionString))
            {
                conn.Open();
                NpgsqlCommand command = new NpgsqlCommand("uuid_generate_v4", conn);
                command.CommandType = CommandType.StoredProcedure;
                newGuid = (Guid)command.ExecuteScalar();
                conn.Close();
            }

            return newGuid;
        }

        public void BDTrackUpdate(Track track)
        {
            using (NpgsqlConnection conn = new NpgsqlConnection(GlobalSettings.connectionString))
            {
                conn.Open();

                NpgsqlCommand command = new NpgsqlCommand("trackouterguid_upd", conn);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("i_recid", track.Recid);
                command.Parameters.AddWithValue("i_outerguid", track.Outerguid);
                command.Parameters.AddWithValue("i_outersource", track.Outersource);

                command.ExecuteNonQuery();

                conn.Close();

            }
        }

        public void BDTrackInsert(Track track)
        {
            using (NpgsqlConnection conn = new NpgsqlConnection(GlobalSettings.connectionString))
            {
                conn.Open();

                NpgsqlCommand command = new NpgsqlCommand("track_insert", conn);
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("i_trackid", track.Recid); 
                command.Parameters.AddWithValue("i_localdevicepathupload", track.Url);
                command.Parameters.AddWithValue("i_path", "/media/store/"+track.Deviceid+"/"+track.Recid+".mp3");
                command.Parameters.AddWithValue("i_deviceid", track.Deviceid);
                command.Parameters.AddWithValue("i_outerguid", track.Outerguid);
                command.Parameters.AddWithValue("i_outersource", track.Outersource);
                command.Parameters.AddWithValue("i_artist", track.Artist);
                command.Parameters.AddWithValue("i_recname", track.Recname);
                command.Parameters.AddWithValue("i_length", track.Length);

                command.ExecuteNonQuery();



                conn.Close();


            }
        }
    }

    public static class GlobalSettings
    {
        public static string connectionString;
        public static string defaultDeviceId;
        public static string mediaDirectory;

        public static void ReadFromJson()
        {
            var builder = new ConfigurationBuilder();
            // установка пути к текущему каталогу
           // builder.SetBasePath(AppContext.BaseDirectory); //для разработки 
            builder.SetBasePath(Directory.GetCurrentDirectory()); //для сервака


            // получаем конфигурацию из файла appsettings.json
            builder.AddJsonFile("appsettings.json");
            // создаем конфигурацию
            var config = builder.Build();
            // получаем строку подключения, ид устройства по умочанию, путь для хранения трэков на диске
            connectionString = config.GetConnectionString("DefaultConnection");
            defaultDeviceId = config.GetSection("DeviceId")["DefaultDeviceId"];
            mediaDirectory = config.GetSection("MediaDirectory")["Directory"];
        }
    }

    public class TracksChecker
    {
       

        List<Track> tracks_out = new List<Track>();

        public List<Track> CheckForNew(List<Track> tracks_in)
        {
            try
            {
                tracks_out.Clear();
                foreach (Track track in tracks_in)
                {


                    using (NpgsqlConnection conn = new NpgsqlConnection(GlobalSettings.connectionString))
                    {
                        conn.Open();
                        string sql = "select outerguid from tracks where outerguid = '" + track.Outerguid + "' limit 1;";

                        using (NpgsqlCommand command = new NpgsqlCommand(sql, conn))
                        {
                            command.CommandType = CommandType.Text;

                            NpgsqlDataReader dr = command.ExecuteReader();

                            if (!dr.HasRows) { tracks_out.Add(track); }

                        }
                        conn.Close();

                    }
                }

                return tracks_out;
            }
            catch(Exception ex)
            {
                throw new Exception(ex.Message);
            }
        }
    }



    public class Track
    {

        public Guid Recid { get; set; }
        public DateTime? Reccreated { get; set; }
        public string Recname { get; set; }
        public DateTime? Recupdated { get; set; }
        public string Localdevicepathupload { get; set; }
        public string Path { get; set; }
        public Guid? Deviceid { get; set; }
        public Guid? Uploaduserid { get; set; }
        public string Artist { get; set; }
        public int? Iscensorial { get; set; }
        public int? Iscorrect { get; set; }
        public int? Isfilledinfo { get; set; }
        public int? Length { get; set; }
        public int? Size { get; set; }
        public int? Isexist { get; set; }
        public string Recdescription { get; set; }
        public string Reccreatedby { get; set; }
        public string Recupdatedby { get; set; }
        public int? Recstate { get; set; }
        public string Reccode { get; set; }
        public Guid Outerguid { get; set; }
        public string Outersource { get; set; }
        public string Url { get; set; }


    }

    public enum ZaycevRubric
    {
        top,
        @new
    }
}
