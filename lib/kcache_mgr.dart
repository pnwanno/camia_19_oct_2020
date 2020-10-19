import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import './dbs.dart';

class KjutCacheMgr{
  DBTables _dbTables=DBTables();

  Future initMgr()async{
    Directory _tmpDir= await getTemporaryDirectory();
    Database _con= await _dbTables.kjutCache();
    int _kita= DateTime.now().millisecondsSinceEpoch;
    List _result= await _con.rawQuery("select * from kcache");
    int _kount= _result.length;
    for(int _k=0; _k<_kount; _k++){
      int _targTime= int.tryParse(_result[_k]["cache_till"]);
      if(_kita > _targTime){
        File _targFile= File(_tmpDir.path + "/" + _result[_k]["fname"]);
        _targFile.exists().then((_fexists) {
          if(_fexists){
            _targFile.delete();
          }
        });
        String _targID= _result[_k]["id"].toString();
        _con.execute("delete from kcache where id=?", [_targID]);
      }
    }
  }

  Future downloadFile(String _url, DateTime expireDate)async{
    try{
      Directory _tmpDir= await getTemporaryDirectory();
      Database _con= await _dbTables.kjutCache();
      List _testResult=await _con.rawQuery("select fname from kcache where url=?", [_url]);
      if(_testResult.length>0){
        return _tmpDir.path + "/" + _testResult[0]["fname"];
      }
      else{
        http.Response _resp= await http.get(_url);
        if(_resp.statusCode ==200) {
          List _result= await _con.rawQuery("select id from kcache order by id desc limit 1");
          int _lastId=0;
          if(_result.length==1){
            _lastId= _result[0]["id"];
          }
          String _cacheTill= expireDate.millisecondsSinceEpoch.toString();
          _lastId++;

          String _dlStatus="pending";
          List<String> _brkURL= _url.split(".");
          String _fext=_brkURL.last;
          String _tmpFname= DateTime.now().millisecondsSinceEpoch.toString() + "$_lastId.$_fext";
          await _con.execute("insert into kcache (url, fname, cache_till, status) values (?, ?, ?, ?)", [
            _url,
            _tmpFname,
            _cacheTill,
            _dlStatus
          ]);
          File _tmpF= File(_tmpDir.path + "/$_tmpFname");
          if(await _tmpF.exists() == false){
            _tmpF.writeAsBytesSync(_resp.bodyBytes);
            await _con.execute("update kcache set status='complete' where url='$_url'");
            return _tmpFname;
          }
          else{
            return _tmpFname;
          }
        }
      }
    }
    catch(ex){

    }
  }//download file

  Future listAvailableCache()async{
    Map _retVal={};
    Directory _tmpDir=await getTemporaryDirectory();
    Database _con= await _dbTables.kjutCache();
    List _result= await _con.rawQuery("select url, fname from kcache where status='complete'");
    int _kount= _result.length;
    for(int _k=0; _k<_kount; _k++){
      String _targUrl= _result[_k]["url"];
      _retVal[_targUrl]= _tmpDir.path + "/" + _result[_k]["fname"];
    }
    return _retVal;
  }
}