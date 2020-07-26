import 'dart:isolate';
import 'dart:async';

StreamController globalCtr= StreamController.broadcast();
kCompute1(localFunction, String uniqueId)async{
  ReceivePort _rp=ReceivePort();
  await Isolate.spawn(localFunction, _rp.sendPort);
  _rp.listen((message) {
    globalCtr.add({
      "sender": uniqueId,
      "message": message
    });
  });
}
