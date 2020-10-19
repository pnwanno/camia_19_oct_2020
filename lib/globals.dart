library camia.globals;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart' as urlLauncher;

String email="";
String password="";
String fullname="";
String phone="";
String dp="";
String userId="";
Color wallContainerShadow= Color.fromRGBO(32, 32, 32, 1);
String noInternet="Kindly ensure that your device is properly connected to the internet";

bool globalWallVideoMute=true;

String globBaseUrl="https://camia.blwcampusministry.com/app-engine/front-api.php";
String globBaseUrl2="https://camia.blwcampusministry.com/app-engine/front-api2.php";
String globBaseTVURL="https://camia.blwcampusministry.com/app-engine/tv-api.php";
String globBaseMiscAPI="https://camia.blwcampusministry.com/app-engine/misc-api.php";
String globBaseCHFinder="https://blwcampusministry.net/chapter_finder/ife_ezolu/zopia_ife_nzuzo/index.php";
String globBaseNewsAPI="https://camia.blwcampusministry.com/app-engine/cm-news-api.php";
String globBaseDMAPI="https://camia.blwcampusministry.com/app-engine/dm-api.php";

List<String> interestCat= [
  "Comedy",
  "Relationship",
  "Celebrity Gists",
  "Music",
  "Movies",
  "Fashion",
  "Health and Fitness",
  "Job Opportunity",
  "Technology",
  "Phones and Devices",
  "Sports",
  "Inspirationals",
  "Politics",
  "Lifestyle and Culture",
  "Clothing",
  "Business",
  "Science",
  "Education",
  "Food",
  "Media Production",
  "Content Creation"
];

//used for magazine
StreamController globalCtr= StreamController.broadcast();

//this section is dedicated to wall positing paraphernalia
StreamController globalWallPostCtr= StreamController.broadcast();
Map wallPostData={
  "state": "passive",
  "title":"",
  "body":"",
  "media": "",
  "text": "",
  "post_id": "",
  "message": ""
};
//end this section is dedicated to wall positing paraphernalia


//this section is dedicated to cam tv positing paraphernalia
StreamController globalTVPostCtr= StreamController.broadcast();
Map tvPostData={
  "state": "passive",
  "title":""
};
//end this section is dedicated to wall positing paraphernalia


enum KWordcase{
  sentence_case,
  proper_case,
  camel_case
}
///Custom method to transform less familiar word cases
String kChangeCase(String word, KWordcase to){
  String _tolower= word.toLowerCase().replaceAll("jesus", "Jesus").replaceAll("christ", "Christ").replaceAll("god", "God");
  List<String> _brkword= _tolower.split(" ");
  int _count= _brkword.length;
  if(to == KWordcase.sentence_case){
    String _firstchar= _tolower.substring(0,1);
    return _firstchar.toUpperCase() + _tolower.substring(1);
  }
  String _retword="";
  for(int _k=0; _k<_count; _k++){
    if(to ==  KWordcase.proper_case){
      _retword += " " + kChangeCase(_brkword[_k], KWordcase.sentence_case);
    }
    else if(to ==  KWordcase.camel_case){
      if(_k == 0){
        _retword=_brkword[0];
      }
      else{
        _retword += " " + kChangeCase(_brkword[_k], KWordcase.sentence_case);
      }
    }
  }
  return _retword.trim();
}

Path logoPath(Size size){
  Path path=Path();
  path.lineTo(size.width * 0.27, size.height);
  path.cubicTo(size.width * 0.23, size.height * 0.98, size.width * 0.17, size.height * 0.92, size.width * 0.15, size.height * 0.88);
  path.cubicTo(size.width * 0.13, size.height * 0.82, size.width * 0.12, size.height * 0.75, size.width * 0.14, size.height * 0.66);
  path.cubicTo(size.width * 0.16, size.height * 0.53, size.width * 0.16, size.height * 0.49, size.width * 0.09, size.height * 0.38);
  path.cubicTo(size.width * 0.02, size.height * 0.26, size.width * 0.01, size.height * 0.24, size.width * 0.02, size.height * 0.18);
  path.cubicTo(size.width * 0.02, size.height * 0.11, size.width * 0.05, size.height * 0.07, size.width * 0.11, size.height * 0.03);
  path.cubicTo(size.width * 0.18, -0.02, size.width * 0.27, -0.01, size.width * 0.41, size.height * 0.08);
  path.cubicTo(size.width * 0.52, size.height * 0.14, size.width * 0.63, size.height * 0.18, size.width * 0.73, size.height * 0.19);
  path.cubicTo(size.width * 0.85, size.height / 5, size.width * 0.88, size.height * 0.22, size.width * 0.93, size.height * 0.26);
  path.cubicTo(size.width * 0.98, size.height * 0.3, size.width * 1.02, size.height * 0.37, size.width * 1.02, size.height * 0.46);
  path.cubicTo(size.width * 1.02, size.height * 0.61, size.width * 0.92, size.height * 0.72, size.width * 0.75, size.height * 0.76);
  path.cubicTo(size.width * 0.65, size.height * 0.79, size.width * 0.61, size.height * 0.81, size.width * 0.55, size.height * 0.89);
  path.cubicTo(size.width * 0.47, size.height * 0.97, size.width * 0.42, size.height, size.width * 0.35, size.height);
  path.cubicTo(size.width * 0.32, size.height, size.width * 0.28, size.height, size.width * 0.27, size.height);
  path.cubicTo(size.width * 0.27, size.height, size.width * 0.27, size.height, size.width * 0.27, size.height);
  path.close();
  return path;
}

class KToolTip extends StatelessWidget{
  final StreamController _controller;
  KToolTip(this._controller);
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _controller.stream,
      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
        if(_snapshot.hasData && _snapshot.data["visible"]){
          Size _screensize=_snapshot.data["size"];
          Offset _pointer=_snapshot.data["pointer"];
          double _containerwidth= (_screensize.width/2) + 70;
          double _containerleft=0;
          double _pointerleft=0;
          TextAlign _txAlign;
          if(_pointer.dx + _containerwidth < _screensize.width){
            _containerleft=_pointer.dx - 16;
            _pointerleft=16;
            _txAlign= TextAlign.left;
          }
          else if(_pointer.dx >= (_screensize.width/2) - 70 && _pointer.dx <= (_screensize.width/2) + 70){
            _containerleft=_pointer.dx + 106 - _containerwidth;
            _pointerleft=_containerwidth - 86;
            _txAlign= TextAlign.center;
          }
          else{
            _containerleft=_pointer.dx + 36 - _containerwidth;
            _pointerleft=_containerwidth - 16 - 16;
            _txAlign= TextAlign.right;
          }

          double _containertop=0;
          double _pointertop=0;
          if((_pointer.dy + 60) < _screensize.height){
            _containertop=_pointer.dy + 12;
            _pointertop=-8;
          }
          else{
            _containertop=_pointer.dy + 12 - 60;
            _pointertop=8;
          }
          return IgnorePointer(
            ignoring: true,
            child:  Stack(
              fit: StackFit.expand,
              overflow: Overflow.visible,
              children: <Widget>[
                Positioned(
                  left: _containerleft,
                  top: _containertop,
                  width: _containerwidth,
                  child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 700),
                    curve: Curves.fastLinearToSlowEaseIn,
                    onEnd: (){
                      Future.delayed(
                          _snapshot.data["duration"],
                              (){
                            _controller.add({
                              "visible":false
                            });
                          }
                      );
                    },
                    builder: (BuildContext _ctx, double _twval, Widget _){
                      return Opacity(
                        opacity: _twval < 0 ? 0 : _twval > 1 ? 1 : _twval,
                        child: Transform.scale(
                          scale: _twval,
                          child: Container(
                            child: Stack(
                              overflow: Overflow.visible,
                              children: <Widget>[
                                Container(
                                  width:_containerwidth,
                                  padding: EdgeInsets.only(left: 16, right: 16,top: 16, bottom: 16),
                                  decoration: BoxDecoration(
                                      color: _snapshot.data["bgcolor"],
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: Text(
                                    _snapshot.data["text"],
                                    style: TextStyle(
                                        color: _snapshot.data["color"]
                                    ),
                                    textAlign: _txAlign,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                  ),
                                ),

                                Positioned(
                                  left: _pointerleft, top: _pointertop,
                                  child: Transform.rotate(
                                    angle: math.pi/4,
                                    child: TweenAnimationBuilder(
                                      tween: Tween<double>(begin:0, end: 1),
                                      duration: Duration(milliseconds: 1000),
                                      curve: Curves.elasticOut,
                                      builder: (BuildContext _ctx, double _innertwval, _){
                                        return Container(
                                          transform: _pointertop.isNegative ?
                                          Matrix4.translationValues(0, (_innertwval * 24) - 24, 0)
                                          : Matrix4.translationValues(0, (_innertwval * -24) + 24, 0),
                                          decoration: BoxDecoration(
                                              color: _snapshot.data["bgcolor"]
                                          ),
                                          width: 16, height: 16,
                                        );
                                      },
                                    ),
                                  ),
                                )

                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          );
        }
        return Container();
      },
    );
  }

  showTip({@required BuildContext context, @required GlobalKey target, @required String text, @required Duration duration, @required Color bgcolor, @required Color textcolor}){
    RenderBox _rb= target.currentContext.findRenderObject();
    Offset _offset= _rb.localToGlobal(Offset.zero);
    Size _globalSize= context.size;
    Offset _pointerOffset;

    if(_offset.dy > _globalSize.height/1.5) {
      _pointerOffset = Offset(_offset.dx, _offset.dy + 24);
    }
    else {
      _pointerOffset = Offset(_offset.dx, _offset.dy - 24);
    }
      _controller.add({
        "pointer": _pointerOffset,
        "size": _globalSize,
        "text": text,
        "bgcolor": bgcolor,
        "color": textcolor,
        "duration": duration,
        "visible": true
      });
    }
}

class KjToast extends StatelessWidget{
  KjToast(this._color, this._screenSize, this._toastCtrl, this._bottomPosition);
  final Size _screenSize;
  final Color _color;
  final StreamController _toastCtrl;
  final double _bottomPosition;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, bottom: _bottomPosition,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          width: _screenSize.width,
          alignment: Alignment.center,
          child: StreamBuilder(
              stream: _toastCtrl.stream,
              builder: (BuildContext ctx,AsyncSnapshot snapshot){
                if(snapshot.hasData){
                  return TweenAnimationBuilder<double>(
                      tween: snapshot.data["visible"] ? Tween<double>(begin: 0, end: 1) : Tween<double>(begin: 1, end: 0),
                      duration: Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      onEnd: (){
                        Future.delayed(
                            snapshot.data["duration"],
                                (){
                              _toastCtrl.add({
                                "visible": false,
                                "text": "",
                                "duration": Duration(milliseconds: 1)
                              });
                            }
                        );
                      },
                      builder: (BuildContext ctx, double dval, Widget w){
                        return Opacity(
                          opacity: dval<0 ? 0 : dval>1 ? 1 : dval,
                          child: Transform.scale(
                              scale: dval,
                            child: Container(
                              width: _screenSize.width - 32,
                              alignment: Alignment.center,
                              padding: EdgeInsets.only(top: 12, bottom: 12),
                              margin: EdgeInsets.only(left: 16, right: 16),
                              decoration: BoxDecoration(
                                color: _color,
                                borderRadius: BorderRadius.circular(16)
                              ),
                              child: Text(
                                snapshot.data["text"],
                                style: TextStyle(
                                    color: Colors.white,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }
                  );
                }
                else{
                  return Container();
                }
              }
          ),
        ),
      ),
    );
  }

  ///Mimics the native android toast
  showToast({String text, Duration duration}){
    _toastCtrl.add({
      "visible": true,
      "text": text,
      "duration": duration
    });
  }//show toast
}




RegExp _htag= RegExp(r"^#[a-z0-9_]+$", caseSensitive: false);
RegExp _href= RegExp(r"[a-z0-9-]+\.[a-z0-9-]+", caseSensitive: false);
RegExp _atTag= RegExp(r"^@[a-z0-9_]+$", caseSensitive: false);
RegExp _isEmail= RegExp(r"^[a-z_0-9.-]+\@[a-z0-9-]+\.[a-z0-9-]+(\.[a-z0-9-]+)*$", caseSensitive: false);
RegExp _phoneExp= RegExp(r"^[0-9 -]{5,}$");
StreamController localLinkTrigger= StreamController.broadcast();
///Tries to open a URL or a local link (an app link)
followLink(String _link){
  if(_isEmail.hasMatch(_link)){
    urlLauncher.canLaunch("mailto:$_link").then((_canLaunch) {
      if(_canLaunch){
        urlLauncher.launch("mailto:$_link");
      }
    });
  }
  else if(_href.hasMatch(_link)){
    String _newhref= "https://" + _link.replaceAll(RegExp(r"^https?:\/\/",caseSensitive: false), "");
    urlLauncher.canLaunch(_newhref).then((_canLaunch) {
      if(_canLaunch){
        urlLauncher.launch(_newhref);
      }
    });
  }
  else if(_phoneExp.hasMatch(_link)){
    String _newphone= "tel:$_link";
    urlLauncher.canLaunch(_newphone).then((_canLaunch) {
      if(_canLaunch){
        urlLauncher.launch(_newphone);
      }
    });
  }
  else if(_atTag.hasMatch(_link)){
    localLinkTrigger.add({"type":"atag", "link": _link});
  }
  else if(_htag.hasMatch(_link)){
    localLinkTrigger.add({"type":"htag", "link": _link});
  }
}

parseTextForLinks(String _textData){
  _textData=_textData.replaceAll("\n", "__kjut__ ");
  List<String> _brkPostText= _textData.split(" ");
  int _brkPostTextCount= _brkPostText.length;
  List<InlineSpan> _postTextSpan= List<InlineSpan>();
  String _curPostText="";
  for(int _j=0; _j<_brkPostTextCount; _j++){
    String _curText=_brkPostText[_j];
    if(_phoneExp.hasMatch(_curText) || _isEmail.hasMatch(_curText) || _htag.hasMatch(_curText) || _atTag.hasMatch(_curText) || _href.hasMatch(_curText)){
      _postTextSpan.add(
          TextSpan(
              text: _curPostText.replaceAll("__kjut__", "\n") + " ",
              style: TextStyle(
                  height: 1.5
              )
          )
      );
      _curPostText="";
      _postTextSpan.add(
          TextSpan(
              text: _curText.replaceAll("__kjut__", "\n") + " ",
              style: TextStyle(
                  color: (_isEmail.hasMatch(_curText)) ? Colors.orange :
                  (_href.hasMatch(_curText) || _phoneExp.hasMatch(_curText)) ? Colors.blue : Colors.blueGrey,
                  height: 1.5
              ),
              recognizer: TapGestureRecognizer()..onTap=(){
                followLink(_curText);
              }
          )
      );
    }
    else{
      _curPostText += _curText.replaceAll("__kjut__", "\n") + " ";
    }
  }
  _postTextSpan.add(
      TextSpan(
          text: _curPostText.replaceAll("__kjut__ ", "\n"),
          style: TextStyle(
              height: 1.5
          )
      )
  );
  return _postTextSpan;
}//parse text for links

convertToK(int val){
  List<String> units=["K", "M", "B"];
  double remain = val/1000;
  int counter=-1;
  if(remain>1) counter++;
  while(remain>999){
    counter++;
    remain /=1000;
  }
  if(counter>-1) return remain.toStringAsFixed(1) + units[counter];
  return "$val";
}//convert to k m or b

String convSecToMin(int secs){
  return (secs/60).floor().toString().padLeft(2,"0") + " : " + (secs % 60).toString().padLeft(2, "0");
}

convSecToHMS(int totalSeconds){
  String h = (totalSeconds / 3600).floor().toString().padLeft(2, "0");
  totalSeconds %= 3600;

  String m = (totalSeconds / 60).floor().toString().padLeft(2, "0");
  String s = (totalSeconds % 60).toString().padLeft(2, "0");
  return "$h:$m:$s";
}


class KjutPullRefresh extends StatefulWidget{
  _KjutPullRefresh createState(){
    return _KjutPullRefresh();
  }
  final double pullRefreshLoadHeight;
  final ScrollController listViewCtr;
  final cb;
  final Widget child;
  KjutPullRefresh({
    this.pullRefreshLoadHeight,
    this.listViewCtr,
    this.cb,
    this.child
  });
}

class _KjutPullRefresh extends State<KjutPullRefresh>{
  @override
  Widget build(BuildContext context) {
    return kjPullToRefresh(child: widget.child);
  }

  StreamController _pullRefreshCtr= StreamController.broadcast();
  double _pullRefreshHeight=0;
  ///Pass a listview as child widget to this widget
  Widget kjPullToRefresh({Widget child}){
    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (PointerUpEvent pue){
          if(_pullRefreshHeight< widget.pullRefreshLoadHeight){
            _pullRefreshHeight =0;
            _pullRefreshCtr.add("kjut");
          }
          else{
            Future.delayed(
                Duration(milliseconds: 1500),
                    (){
                  //call the refresh function
                  _pullRefreshHeight=0;
                  _pullRefreshCtr.add("kjut");
                  widget.cb();
                }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(widget.listViewCtr.position.atEdge && !_delta.direction.isNegative){
            double dist= math.sqrt(_delta.distanceSquared);
            if(_pullRefreshHeight < widget.pullRefreshLoadHeight){
              _pullRefreshHeight +=(dist/3);
              _pullRefreshCtr.add("kjut");
            }
          }
        },
        child: child
    );
  }//kjut pull to refresh

  @override
  void dispose() {
    super.dispose();
    _pullRefreshCtr.close();
  }
}