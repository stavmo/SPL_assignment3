package bgu.spl.net.srv;

import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;

public interface Connections<T> {

    boolean send(int connectionId, T msg);

    void send(String channel, T msg);

    void disconnect(int connectionId);


    //added these two methods to call them in process in StompProtocol  - TODO: need to check if it's okay

    void subscribe(int connectionId, String channel, String subscriptionID);

    void unsubscribe(int connectionId, String channel);

    //helpers - TODO: need to check if it's okay
    public ConcurrentHashMap<Integer, String> getSubscribers(String destination);
    public String getSubscriptionId(int connectionId, String destination);
    public String getDestinationBySubId(int connectionId, String subId);


}
