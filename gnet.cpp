#include "GArgs.h"
#include "GStr.h"
#include "GVec.hh"
#include "GHash.hh"
#include "GThreads.h"
#include "gsocket.h"

#define USAGE "Usage:\n\
gnet [-S|-s <port>] | -c <server>[:<port>]] [<text_message>]\n\
\n\
Options:\n\
 -S|s <port> server mode: start a TCP listening server on port <port>\n\
           (default 8090)\n\
 -c <server>[:<port>] client mode (default): connect to server <server>\n\
           (default:localhost) on port <port> (default 8090)\n\
In client mode, if argument <text_message> is not provided the program will \n\
enter interactive mode, sending to the server anything that the user types.\n\
"

bool isServer=false;
unsigned short  port=8090;
GStr server("localhost");

const unsigned int RCVBUFSIZE = 1024;

void HandleTCPClient(GTCPSocket *sock); // Server mode: TCP client handling function


int main(int argc, char * const argv[]) {
 //GArgs args(argc, argv, "hg:c:s:t:o:p:help;genomic-fasta=COV=PID=seq=out=disable-flag;test=");
 GArgs args(argc, argv, "hSs:c:");
 fprintf(stderr, "Command line was:\n");
 args.printCmdLine(stderr);
 args.printError(USAGE, true);
 if (args.getOpt('h') || args.getOpt("help")) {
     GMessage("%s\n", USAGE);
     exit(1);
 }
 GStr s(args.getOpt('s'));
 if (!s.is_empty()) {
   isServer=true;
   port=s.asInt();
   if (port<=0) 
     GError("%sError: could not parse server port!\n",USAGE);
 }
 if (args.getOpt('S')) {
  isServer=true;
 }
 s=args.getOpt('c');
 if (!s.is_empty()) {
    GStr token;
    if (isServer)
       GError("%sError: cannot use -c option for server mode!\n", USAGE);
    isServer=false;
    s.startTokenize(":", tkFullString);
    s.nextToken(token);
    if (!token.is_empty())
       server=token;
    if (s.nextToken(token)) {
      port=token.asInt();
      if (port<=0)
        GError("%sError: could not parse server port!\n",USAGE);
    }
 }
 int msgcount=args.startNonOpt();
 if (isServer) {
   //Server mode
   GMessage("Server mode: start listening on port %d\n", 
             port);
   //server code here
   GTCPServerSocket servSock(port);
   while (true) {
     HandleTCPClient(servSock.accept());
   }
   
   return 0;
 }
 
 //Client mode
 if (msgcount==0) {
   GMessage("Client mode: no message(s) given, nothing to do.\n");
   return 0;
 }
 //client code here
 GMessage("Client mode: connecting to server %s port %d\n", 
        server.chars(), port);
 while (true) {
     GStr msg(args.nextNonOpt());
     if (msg.is_empty()) break;
     GTCPSocket sock(server, port);
     GMessage("[Sending message to server:] \"%s\"\n", msg.chars());
     sock.send(msg);
     // Receive the response (echo?) line from the server
     GStr r(sock.recvline());
     if (!r.is_empty()) {
        GMessage("[Server replied:] \"%s\"\n", r.chars());
     }
 }
 return 0;
}

// TCP client handling function
void HandleTCPClient(GTCPSocket *sock) {
  GMessage("[Server handling client ");
  GStr caddr(sock->getForeignAddress());
  if (caddr.is_empty()) GMessage("[unknown]");
      else GMessage(caddr.chars());
  GMessage(" on port ");
  unsigned short cport=sock->getForeignPort();
  if (cport) GMessage("%d]\n",cport);
      else GMessage(" [unknown] ]\n");
  // Send received string and receive again until the end of transmission
  char echoBuffer[RCVBUFSIZE+1];
  int recvMsgSize;
  GStr r;
  while ((recvMsgSize = sock->recv(echoBuffer, RCVBUFSIZE)) > 0) { // Zero means
                                                         // end of transmission
    // Echo message back to client
    echoBuffer[recvMsgSize]='\0';
    GMessage("[received:] \"%s\"\n",echoBuffer);
    GStr r(echoBuffer);
    r.append('\n');
    //sock->send(echoBuffer, recvMsgSize);
    sock->send(r);
  }
  delete sock;
}
