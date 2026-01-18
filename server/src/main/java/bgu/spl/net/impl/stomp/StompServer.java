package bgu.spl.net.impl.stomp;

import bgu.spl.net.srv.StompServerInter;


public class StompServer {

    public static void main(String[] args) {
        int port;
        String serverType;
        int currentConnection


        try {
            port = Integer.parseInt(args[0]);
            serverType = args[1];
            if (!serverType.equals("tpc") && !serverType.equals("reactor")) {
                throw new IllegalArgumentException();
            }
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid port number or server type");
        }

        if (serverType.equals("tpc")){
        StompServerInter.threadPerClient(
                port,
                () -> new StompProtocol(), //protocol factory
                () -> new StompEncDec()//message encoder decoder factory
        ).serve();
        }

        // Server.reactor(
        //         Runtime.getRuntime().availableProcessors(),
        //         7777, //port
        //         () -> new EchoProtocol<>(), //protocol factory
        //         LineMessageEncoderDecoder::new //message encoder decoder factory
        // ).serve();
    }
}
