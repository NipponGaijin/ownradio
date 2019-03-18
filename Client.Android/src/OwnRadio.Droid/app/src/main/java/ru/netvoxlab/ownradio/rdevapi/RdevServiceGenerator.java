package ru.netvoxlab.ownradio.rdevapi;

import okhttp3.OkHttpClient;
import okhttp3.logging.HttpLoggingInterceptor;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;

public class RdevServiceGenerator {
    public static final String API_BASE_URL = "http://rdev.ownradio.ru/"; //"http://api.ownradio.ru/";//Базовая часть адреса //localhost for emulator "http://10.0.2.2:8080"




    private static OkHttpClient.Builder httpClient = new OkHttpClient.Builder();

    private static Retrofit.Builder builder =
            new Retrofit.Builder()
                    .baseUrl(API_BASE_URL)
                    .addConverterFactory(GsonConverterFactory.create());//Конвертер, необходимый для преобразования JSON'а в объекты

    public static <S> S createService(Class<S> serviceClass) {

        HttpLoggingInterceptor logging = new HttpLoggingInterceptor();
        logging.setLevel(HttpLoggingInterceptor.Level.BODY);
//        httpClient.addInterceptor(logging);

        Retrofit retrofit = builder.client(httpClient.build()).build();
        return retrofit.create(serviceClass);//Создаем объект, при помощи которого будем выполнять запросы
    }
}
