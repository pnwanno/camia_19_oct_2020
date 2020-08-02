
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../dbs.dart';
import './affirmation_details.dart';
import '../globals.dart' as globals;
class IAffirm extends StatefulWidget{
  _IAffirm createState(){
    return _IAffirm();
  }
}

class _IAffirm extends State<IAffirm>{
  double _gridMaxExtent;
  double _gridChildSpacing;
  DBTables _dbTables=DBTables();
  Future<Widget> fetchAffirmationofDay()async{
    _gridMaxExtent=_screenSize.width< 750 ? _screenSize.width/2.2: _screenSize.width/4.2;
    _gridChildSpacing= _screenSize.width<750 ? (_screenSize.width/2)  - (_screenSize.width/2.2): (_screenSize.width/4) - (_screenSize.width/4.2);
    Database _con= await _dbTables.lwDict();
    var _result= await _con.rawQuery("select * from affirmations order by id desc");
    int _count=_result.length;
    return GridView.builder(
        itemCount: _count,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _gridMaxExtent,
            crossAxisSpacing: _gridChildSpacing,
            mainAxisSpacing: 12
        ),
        itemBuilder: (BuildContext _ctx, int _itemIndex){
          return Container(
            padding: EdgeInsets.only(left: 12, right: 12, top: 16, bottom: 16),
            decoration: BoxDecoration(
                color: Color.fromRGBO(240, 240, 240, 1),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    offset: Offset(1,1),
                    color: Color.fromRGBO(220, 220, 220, 1),
                    blurRadius: 2,
                  )
                ]
            ),
            child: GestureDetector(
              onTap: (){
                Navigator.of(_pageContext).push(MaterialPageRoute(
                    builder: (BuildContext _ctx){
                      return AffirmationDetails(_result[_itemIndex]["id"]);
                    }
                ));
              },
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(bottom: 9),
                      child: Text(
                        _result[_itemIndex]["day"],
                        style: TextStyle(
                            fontSize: 18,
                            fontFamily: "ubuntu",
                            color: Colors.blueGrey
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(bottom: 3),
                      child: Text(
                        globals.kChangeCase(_result[_itemIndex]["text"], globals.KWordcase.sentence_case),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18
                        ),
                      ),
                    ),
                    Container(
                      child: Text(
                        "Read more ..."
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }
    );
  }//fetch affirmation

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize= MediaQuery.of(_pageContext).size;
    debugPrint("screen $_screenSize");
    return Scaffold(
      backgroundColor: Color.fromRGBO(230, 230, 230, 1),
      body: Container(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
        height: _screenSize.height, width: _screenSize.width,
        alignment: Alignment.center,
        child: FutureBuilder(
          future: fetchAffirmationofDay(),
          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
            if(_snapshot.hasData){
              return _snapshot.data;
            }
            else{
              return CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }//route's build method
}