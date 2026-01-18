package bgu.spl.net.srv;

import java.io.IOException;

public interface Connections<T> {

    boolean send(int connectionId, T msg);

    void send(String channel, T msg);

    void disconnect(int connectionId);


    //added these two methods to call them in process in StompProtocol 

    void subscribe(int connectionId, String channel);

    void unsubscribe(int connectionId, String channel);
}
