package ru.netvoxlab.ownradio.rdevapi;

import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.preference.PreferenceManager;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Map;

import okhttp3.ResponseBody;
import retrofit2.Response;
import ru.netvoxlab.ownradio.APIService;
import ru.netvoxlab.ownradio.App;
import ru.netvoxlab.ownradio.ServiceGenerator;
import ru.netvoxlab.ownradio.TrackDataAccess;
import ru.netvoxlab.ownradio.TrackToCache;
import ru.netvoxlab.ownradio.Utilites;
import ru.netvoxlab.ownradio.rdevApiObjects.GetTrackFilestream;

import static ru.netvoxlab.ownradio.Constants.TAG;
import static ru.netvoxlab.ownradio.MainActivity.ActionTrackInfoUpdate;

public class RdevGetTrack extends AsyncTask<Map<String, String>, Void, Boolean> {
    Context mContext;
    SharedPreferences sp;
    public RdevGetTrack(Context context){
        this.mContext = context;
        this.sp = PreferenceManager.getDefaultSharedPreferences(mContext);
    }

    @Override
    protected Boolean doInBackground(Map<String, String>... trackMap) {
        Long fileLength;
        GetTrackFilestream body = new GetTrackFilestream(trackMap[0].get("recid"));
        try {
            Response<ResponseBody> response;
            String token = sp.getString("authToken", "");
            response = RdevServiceGenerator.createService(RdevAPIService.class).getTrackFilestream("Bearer " + token, body).execute();
            if (response.code() == 200) {
                Log.d(TAG, "server contacted and has file");
                final String trackURL = ((App) mContext).getMusicDirectory() + File.separator + trackMap[0].get("recid") + ".mp3";
//				final String trackURL = mContext.getExternalFilesDir(Environment.DIRECTORY_MUSIC) + File.separator + trackMap[0].get("id") + ".mp3";
                boolean writtenToDisk = WriteTrackToDisk2(trackURL, response.body());

                if (writtenToDisk == true) {
                    fileLength = new File(trackURL).length();

                    ContentValues track = new ContentValues();
                    track.put("id", trackMap[0].get("recid"));
                    track.put("trackurl", trackURL);
                    track.put("datetimelastlisten", "");
                    track.put("isexist", "1");
                    track.put("title", trackMap[0].get("recname"));
                    track.put("artist", trackMap[0].get("artist"));
                    track.put("length", Double.valueOf(trackMap[0].get("length")));
                    track.put("methodnumber", trackMap[0].get("method"));

                    if (fileLength.equals(Long.valueOf(response.headers().get("Content-Length")))) {

                        new TrackDataAccess(mContext).SaveTrack(track);
                        new Utilites().SendInformationTxt(mContext, "File " + trackMap[0].get("recid") + " is load");

                        Intent in = new Intent(ActionTrackInfoUpdate);
                        mContext.sendBroadcast(in);
//					Process process = null;
//					DataOutputStream dataOutputStream = null;

//					try {
//						process = Runtime.getRuntime().exec("su");
//						dataOutputStream = new DataOutputStream(process.getOutputStream());
//						dataOutputStream.writeBytes("chmod 644 " + trackURL + "\n");
//						dataOutputStream.writeBytes("exit\n");
//						dataOutputStream.flush();
//						process.waitFor();
//					} catch (Exception e) {
//						return false;
//					} finally {
//						try {
//							if (dataOutputStream != null) {
//								dataOutputStream.close();
//							}
//							process.destroy();
//						} catch (Exception e) {
//						}
//					}
                        return true;
                    } else {
                        new Utilites().SendInformationTxt(mContext, "<font color='red'>При загрузке трека " + trackMap[0].get("id") +
                                " не совпала длина файла: <br/>" + response.headers().get("Content-Length").toString() + " байт отдано с сервера (response Content-length), <br/>" +
                                response.body().contentLength() + " байт отдано с сервера (body Content-length), <br/>" +
                                fileLength.toString() + " байт скачано</font>");
//						new Utilites().SendLogs(mContext, trackMap[0].get("deviceid"));

                        new TrackToCache(mContext).DeleteTrackFromCache(track);
//						MediaPlayerService.player.pause();
//						Intent intent = new Intent(ActionButtonImgUpdate);
//						mContext.sendBroadcast(intent);
                        return false;
                    }
                }
            }else if(response.code() == 401){
                new Utilites().SendInformationTxt(mContext, "Unauthorized");
                Log.d("Unauth", String.valueOf(response.code()));
                return null;
            }
            else {
                new Utilites().SendInformationTxt(mContext, "server contact failed");
                return false;
            }
        } catch (Exception ex) {
            new Utilites().SendInformationTxt(mContext, " " + ex.getLocalizedMessage());
            return false;
        }
        return false;
    }

    protected void onPostExecute(Boolean o) {
        super.onPostExecute(o);
    }

    public boolean WriteTrackToDisk2(String trackURL, ResponseBody body) {

        try {
            File futureMusicFile = new File(trackURL);

            InputStream inputStream = null;
            OutputStream outputStream = null;

            try {
                byte[] fileReader = new byte[4096];

                long fileSize = body.contentLength();
                long fileSizeDownloaded = 0;

                inputStream = body.byteStream();
                outputStream = new FileOutputStream(futureMusicFile);

                while (true) {
                    int read = inputStream.read(fileReader);

                    if (read == -1) {
                        break;
                    }

                    outputStream.write(fileReader, 0, read);

                    fileSizeDownloaded += read;

//					Log.d(TAG, "file download: " + fileSizeDownloaded + " of " + fileSize);
                }

                outputStream.flush();

                return true;
            } catch (IOException e) {
                return false;
            } finally {
                if (inputStream != null) {
                    inputStream.close();
                }

                if (outputStream != null) {
                    outputStream.close();
                }
            }
        } catch (IOException e) {
            return false;
        }
    }
}
