library camia.globals;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

String email="";
String password="";
String fullname="";
String phone="";
String dp="";
String userId="";
Color wallContainerShadow= Color.fromRGBO(32, 32, 32, 1);

String globBaseUrl="https://camia.blwcampusministry.com/app-engine/front-api.php";
String globBaseUrl2="https://camia.blwcampusministry.com/app-engine/front-api2.php";

StreamController globalCtr= StreamController.broadcast();

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

class KjToast extends StatelessWidget{
  KjToast(this._globalFontSize, this._screenSize, this._toastCtrl, this._bottomPosition);
  final Size _screenSize;
  final double _globalFontSize;
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
                if(snapshot.hasData && snapshot.data["visible"]){
                  return TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: _screenSize.width * .5,
                          end: _screenSize.width - 32
                      ),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
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
                        return AnimatedContainer(
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(left:16, right:16, top:9, bottom: 9),
                            margin: EdgeInsets.only(left:16, right: 16),
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(5, 5, 5, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            duration: Duration(milliseconds: 100),
                            width: dval,
                            child: AnimatedOpacity(
                              opacity: dval< (_screenSize.width - 32) ? 0 : 1,
                              duration: Duration(milliseconds: 500),
                              child: Text(
                                dval< (_screenSize.width - 32) ? "" : snapshot.data["text"],
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _globalFontSize + 1
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            )
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