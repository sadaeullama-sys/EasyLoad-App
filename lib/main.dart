
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 await DB.i.open();
 runApp(const App());
}
const red=Color(0xFFD00018), navy=Color(0xFF101B29);
final fmt=NumberFormat('#,##0.00');
class DB {
 DB._(); static final i=DB._(); late Database db;
 Future<void> open() async {
  db=await openDatabase(p.join(await getDatabasesPath(),'easyload.db'),version:3,onCreate:(d,v) async {
   for(final sql in [
    'CREATE TABLE items(id INTEGER PRIMARY KEY,name TEXT NOT NULL,category TEXT,qty REAL,buy REAL,sell REAL,barcode TEXT,qr_code TEXT,imei TEXT,notes TEXT,created TEXT)',
    'CREATE TABLE purchases(id INTEGER PRIMARY KEY,item_id INTEGER,item_name TEXT,code TEXT,qty REAL,unit_cost REAL,total REAL,supplier TEXT,note TEXT,created TEXT)',
    'CREATE TABLE sales(id INTEGER PRIMARY KEY,serial TEXT,item_id INTEGER,item_name TEXT,qty REAL,unit_price REAL,total REAL,paid REAL,customer TEXT,method TEXT,note TEXT,unit_cost REAL DEFAULT 0,created TEXT)',
    'CREATE TABLE payments(id INTEGER PRIMARY KEY,party TEXT,item_name TEXT,kind TEXT,amount REAL,method TEXT,note TEXT,created TEXT)',
    'CREATE TABLE adjustments(id INTEGER PRIMARY KEY,item_name TEXT,qty REAL,reason TEXT,created TEXT)',
    'CREATE TABLE expenses(id INTEGER PRIMARY KEY,category TEXT,amount REAL,note TEXT,created TEXT)',
    'CREATE TABLE customers(id INTEGER PRIMARY KEY,name TEXT,phone TEXT,address TEXT,note TEXT,created TEXT)',
    'CREATE TABLE service_transactions(id INTEGER PRIMARY KEY,service TEXT,txn_type TEXT,amount REAL,commission REAL,customer TEXT,reference TEXT,note TEXT,network TEXT,created TEXT)',
    'CREATE TABLE rso_daily(id INTEGER PRIMARY KEY,ledger_date TEXT,company TEXT,opening REAL,load2 REAL,sale REAL,rso_remaining REAL,transfer REAL,katta REAL,note TEXT)',
    'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)',
    'CREATE TABLE payment_requests(id INTEGER PRIMARY KEY AUTOINCREMENT,email TEXT,plan TEXT,amount REAL,method TEXT,payer_name TEXT,payer_phone TEXT,transaction_id TEXT,status TEXT,created TEXT)'
   ]) { await d.execute(sql); }
   await d.insert('settings',{'key':'user','value':'admin'});
   await d.insert('settings',{'key':'pin','value':'1234'});
   await d.insert('settings',{'key':'shop','value':'EasyLoad Shop Manager'});
   await d.insert('settings',{'key':'trial_started', 'value':DateTime.now().toIso8601String()});
   await d.insert('settings',{'key':'subscription_status','value':'trial'});
   await d.insert('settings',{'key':'subscription_until','value':''});
   await d.insert('settings',{'key':'jazzcash_title','value':''});
   await d.insert('settings',{'key':'jazzcash_number','value':''});
   await d.insert('settings',{'key':'easypaisa_title','value':''});
   await d.insert('settings',{'key':'easypaisa_number','value':''});
  },onUpgrade:(d,oldVersion,newVersion) async {
   if(oldVersion<3) {
    await d.execute('CREATE TABLE IF NOT EXISTS adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT,item_name TEXT NOT NULL,qty REAL NOT NULL,reason TEXT,created TEXT NOT NULL)');
    Future<void> addColumn(String table,String column,String type) async { final cols=(await d.rawQuery('PRAGMA table_info($table)')).map((r)=>r['name']).toSet(); if(!cols.contains(column)) await d.execute('ALTER TABLE $table ADD COLUMN $column $type'); }
    await addColumn('payments','item_name','TEXT'); await addColumn('payments','method','TEXT');
    await addColumn('items','qr_code','TEXT'); await addColumn('items','imei','TEXT'); await addColumn('items','notes','TEXT'); await addColumn('items','created','TEXT');
    await addColumn('purchases','item_id','INTEGER'); await addColumn('purchases','code','TEXT'); await addColumn('purchases','note','TEXT');
    await addColumn('sales','serial','TEXT'); await addColumn('sales','item_id','INTEGER'); await addColumn('sales','method','TEXT'); await addColumn('sales','note','TEXT'); await addColumn('sales','unit_cost','REAL DEFAULT 0');
    await addColumn('service_transactions','txn_type','TEXT'); await addColumn('service_transactions','reference','TEXT'); await addColumn('service_transactions','note','TEXT'); await addColumn('service_transactions','network','TEXT');
    await addColumn('customers','note','TEXT'); await addColumn('customers','created','TEXT');
   }
   if(oldVersion<2) {
    await d.execute('CREATE TABLE IF NOT EXISTS payment_requests(id INTEGER PRIMARY KEY AUTOINCREMENT,email TEXT,plan TEXT,amount REAL,method TEXT,payer_name TEXT,payer_phone TEXT,transaction_id TEXT,status TEXT,created TEXT)');
    for(final entry in <String,String>{
      'trial_started':DateTime.now().toIso8601String(),
      'subscription_status':'trial','subscription_until':'',
      'jazzcash_title':'','jazzcash_number':'','easypaisa_title':'','easypaisa_number':''
    }.entries) {
      await d.insert('settings',{'key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.ignore);
    }
   }
  });
  // Defensive defaults for an existing database upgraded from older builds.
  for(final entry in <String,String>{
   'trial_started':DateTime.now().toIso8601String(),
   'subscription_status':'trial','subscription_until':'',
   'jazzcash_title':'','jazzcash_number':'','easypaisa_title':'','easypaisa_number':''
  }.entries) {
   await db.insert('settings',{'key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.ignore);
  }
 }
 Future<String> setting(String key,String fallback) async {
  final r=await db.query('settings',where:'key=?',whereArgs:[key],limit:1);
  return r.isEmpty?fallback:'${r.first['value']??fallback}';
 }
 Future<void> setSetting(String key,String value) async {
  await db.insert('settings',{'key':key,'value':value},conflictAlgorithm:ConflictAlgorithm.replace);
 }
 Future<int> daysLeftInTrial() async {
  final raw=await setting('trial_started',DateTime.now().toIso8601String());
  final start=DateTime.tryParse(raw)??DateTime.now();
  final end=start.add(const Duration(days:7));
  final seconds=end.difference(DateTime.now()).inSeconds;
  return seconds<=0?0:((seconds+86399)~/86400);
 }
 Future<bool> hasActiveSubscription() async {
  final status=await setting('subscription_status','trial');
  final until=DateTime.tryParse(await setting('subscription_until',''));
  return status=='active' && until!=null && until.isAfter(DateTime.now());
 }
 Future<List<Map<String,Object?>>> all(String t)=>db.query(t,orderBy:'id DESC');
 Future<double> total(String t,String c) async {final r=await db.rawQuery('SELECT COALESCE(SUM($c),0) x FROM $t');return (r.first['x'] as num).toDouble();}
}
class App extends StatelessWidget {const App({super.key}); @override Widget build(BuildContext c)=>MaterialApp(title:'EasyLoad Shop Manager',debugShowCheckedModeBanner:false,theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:red),useMaterial3:true),home:const SubscriptionGate());}
class Login extends StatefulWidget {const Login({super.key});@override State<Login> createState()=>_LoginState();}
class _LoginState extends State<Login>{
 final u=TextEditingController(text:'admin'),pw=TextEditingController();String err='';
 @override Widget build(BuildContext c)=>Scaffold(body:Center(child:Card(margin:const EdgeInsets.all(24),child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
 Image.asset('assets/easyload_logo.png',height:115,fit:BoxFit.contain),const Text('EasyLoad Shop Manager',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
 TextField(controller:u,decoration:const InputDecoration(labelText:'Username')),TextField(controller:pw,obscureText:true,decoration:const InputDecoration(labelText:'Password')),
 if(err.isNotEmpty)Text(err,style:const TextStyle(color:red)),
 FilledButton(onPressed:()async{final a=(await DB.i.db.query('settings',where:'key=?',whereArgs:['user'])).first['value'];final b=(await DB.i.db.query('settings',where:'key=?',whereArgs:['pin'])).first['value'];if(u.text==a&&pw.text==b){if(c.mounted)Navigator.pushReplacement(c,MaterialPageRoute(builder:(_)=>const Home()));}else{setState(()=>err='Login incorrect');}},child:const Text('Login')),
 const Text('First login: admin / 1234',style:TextStyle(fontSize:12,color:Colors.grey))
 ])))));
 }
}
class Home extends StatefulWidget {const Home({super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
 int ix=0; final names=['Dashboard','Sales','Purchase','Stock Management','Products / Items','EasyPaisa','JazzCash','EasyLoad','Customers','Suppliers','Payments / Receipts','Stock Adjustments','Expenses','EasyLoad Hisab','Profit & Loss','Reports','Backup / Restore','QR / Barcode Scanner','Settings','Subscription'];
 final icons=[Icons.dashboard,Icons.point_of_sale,Icons.shopping_cart,Icons.inventory_2,Icons.qr_code,Icons.account_balance_wallet,Icons.account_balance_wallet,Icons.phone_android,Icons.people,Icons.local_shipping,Icons.receipt_long,Icons.warning_amber,Icons.money_off,Icons.calculate,Icons.trending_up,Icons.analytics,Icons.backup,Icons.qr_code_scanner,Icons.settings,Icons.workspace_premium];
 @override Widget build(BuildContext c){final pages=[const Dashboard(),const SalePage(),const PurchasePage(),const StockPage(),const StockPage(),const ServicePage(serviceOnly:'EasyPaisa'),const ServicePage(serviceOnly:'JazzCash'),const ServicePage(serviceOnly:'EasyLoad'),const CustomerPage(),const SupplierPage(),const PaymentPage(),const StockAdjustmentPage(),const ExpensePage(),const RsoPage(),const ProfitLossPage(),const ReportPage(),const BackupRestorePage(),const ScannerPage(),const SettingsPage(),const SubscriptionPage()];return Scaffold(appBar:AppBar(title:Text(names[ix]),backgroundColor:navy,foregroundColor:Colors.white,actions:[Padding(padding:const EdgeInsets.only(right:12),child:Image.asset('assets/easyload_logo.png',height:36,width:42,fit:BoxFit.contain))]),drawer:Drawer(child:ListView(children:[DrawerHeader(decoration:const BoxDecoration(color:navy),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Image.asset('assets/easyload_logo.png',height:78,fit:BoxFit.contain),const Text('EasyLoad Shop Manager',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold))])),for(int i=0;i<names.length;i++)ListTile(leading:Icon(icons[i]),title:Text(names[i]),selected:ix==i,onTap:(){setState(()=>ix=i);Navigator.pop(c);})])),body:pages[ix]);}
}
class Dashboard extends StatefulWidget {const Dashboard({super.key});@override State<Dashboard> createState()=>_DashboardState();}
class _DashboardState extends State<Dashboard>{Map<String,String> vals={};@override void initState(){super.initState();load();}Future<void>load()async{vals={'Stock Items':'${(await DB.i.db.rawQuery('SELECT COUNT(*) n FROM items')).first['n']}','Sales':'Rs. ${fmt.format(await DB.i.total('sales','total'))}','Purchases':'Rs. ${fmt.format(await DB.i.total('purchases','total'))}','Payments':'Rs. ${fmt.format(await DB.i.total('payments','amount'))}','Expenses':'Rs. ${fmt.format(await DB.i.total('expenses','amount'))}'};if(mounted)setState((){});}@override Widget build(BuildContext c)=>RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(14),children:[const Text('Shop Overview',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,children:vals.entries.map((e)=>Card(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(e.key),Text(e.value,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))])))).toList()),const Text('Offline SQLite storage is enabled.'),const Text('Developer: Muhammad Ilyas') ]));}
class EntryPage extends StatefulWidget {final String title,table;final List<String> fields;const EntryPage(this.title,this.table,this.fields,{super.key});@override State<EntryPage> createState()=>_EntryPageState();}
class _EntryPageState extends State<EntryPage>{final ctrls=<String,TextEditingController>{};List<Map<String,Object?>> rows=[];@override void initState(){super.initState();for(final f in widget.fields)ctrls[f]=TextEditingController();load();}Future<void>load()async{rows=await DB.i.all(widget.table);if(mounted)setState((){});}Future<void>save()async{final data=<String,Object?>{};for(final f in widget.fields){final v=ctrls[f]!.text;data[f]=double.tryParse(v)??v;}await DB.i.db.insert(widget.table,data);for(final x in ctrls.values)x.clear();await load();} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[Text(widget.title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final f in widget.fields)TextField(controller:ctrls[f],decoration:InputDecoration(labelText:f.replaceAll('_',' '))),FilledButton(onPressed:save,child:const Text('Save Record')),const Divider(),...rows.map((r)=>Card(child:ListTile(title:Text(r.entries.take(2).map((e)=>'${e.key}: ${e.value??''}').join(' • ')),subtitle:Text(r.entries.skip(2).map((e)=>'${e.key}: ${e.value??''}').join(' | '))))) ]);}
class StockPage extends StatefulWidget{const StockPage({super.key});@override State<StockPage> createState()=>_StockPageState();}
class _StockPageState extends State<StockPage>{final n=TextEditingController(),q=TextEditingController(text:'0'),b=TextEditingController(text:'0'),s=TextEditingController(text:'0'),cat=TextEditingController(),code=TextEditingController();List<Map<String,Object?>> rows=[];Future<void>load()async{rows=await DB.i.all('items');if(mounted)setState((){});}@override void initState(){super.initState();load();}Future<void>save()async{if(n.text.trim().isEmpty)return;await DB.i.db.insert('items',{'name':n.text,'category':cat.text,'qty':double.tryParse(q.text)??0,'buy':double.tryParse(b.text)??0,'sell':double.tryParse(s.text)??0,'barcode':code.text});await load();}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[const Text('Stock Management',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final x in [('Item name',n),('Category',cat),('Quantity',q),('Buy price',b),('Sell price',s),('Barcode / QR',code)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1)),FilledButton(onPressed:save,child:const Text('Add Stock Item')),const Divider(),...rows.map((r)=>ListTile(title:Text('${r['name']}'),subtitle:Text('Qty ${r['qty']} • Buy ${r['buy']} • Sell ${r['sell']} • ${r['barcode']??''}')))]);}
class PurchasePage extends StatefulWidget{const PurchasePage({super.key});@override State<PurchasePage> createState()=>_PurchasePageState();}
class _PurchasePageState extends State<PurchasePage>{final item=TextEditingController(),qty=TextEditingController(),rate=TextEditingController(),supplier=TextEditingController();Future<void>save()async{final q=double.tryParse(qty.text)??0,r=double.tryParse(rate.text)??0;if(item.text.isEmpty||q<=0)return;await DB.i.db.insert('purchases',{'item_name':item.text,'qty':q,'unit_cost':r,'total':q*r,'supplier':supplier.text,'created':DateTime.now().toIso8601String()});final a=await DB.i.db.query('items',where:'name=?',whereArgs:[item.text]);if(a.isEmpty){await DB.i.db.insert('items',{'name':item.text,'qty':q,'buy':r,'sell':0});}else{await DB.i.db.rawUpdate('UPDATE items SET qty=qty+?,buy=? WHERE id=?',[q,r,a.first['id']]);}if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Purchase saved and stock updated')));setState((){});}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[const Text('Purchase',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final x in [('Item name',item),('Quantity',qty),('Unit cost Rs',rate),('Supplier',supplier)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1)),FilledButton(onPressed:save,child:const Text('Save Purchase'))]);}
class SalePage extends StatefulWidget{const SalePage({super.key});@override State<SalePage> createState()=>_SalePageState();}
class _SalePageState extends State<SalePage>{final item=TextEditingController(),qty=TextEditingController(text:'1'),price=TextEditingController(),paid=TextEditingController(text:'0'),customer=TextEditingController();Future<void>save()async{final q=double.tryParse(qty.text)??0,r=double.tryParse(price.text)??0,pd=double.tryParse(paid.text)??0;final a=await DB.i.db.query('items',where:'name=?',whereArgs:[item.text]);if(a.isEmpty||q<=0||(a.first['qty'] as num)<q){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Item not found or stock insufficient')));return;}await DB.i.db.insert('sales',{'item_name':item.text,'qty':q,'unit_price':r,'total':q*r,'paid':pd,'customer':customer.text,'created':DateTime.now().toIso8601String()});await DB.i.db.rawUpdate('UPDATE items SET qty=qty-? WHERE id=?',[q,a.first['id']]);await DB.i.db.insert('payments',{'party':customer.text,'kind':'Sale received','amount':pd,'note':item.text,'created':DateTime.now().toIso8601String()});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sale completed')));}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[const Text('Sale',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),for(final x in [('Item name',item),('Quantity',qty),('Unit price Rs',price),('Received Rs',paid),('Customer',customer)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1)),FilledButton(onPressed:save,child:const Text('Complete Sale'))]);}
class ServicePage extends StatefulWidget{final String? serviceOnly;const ServicePage({super.key,this.serviceOnly});@override State<ServicePage> createState()=>_ServicePageState();}
class _ServicePageState extends State<ServicePage>{String svc='Jazz';final amount=TextEditingController(),commission=TextEditingController(text:'0'),customer=TextEditingController();final services=['Jazz','Zong','Telenor','Ufone','One Load','Udhaar App','Cash','EasyPaisa','JazzCash'];Future<void>save()async{await DB.i.db.insert('service_transactions',{'service':svc,'amount':double.tryParse(amount.text)??0,'commission':double.tryParse(commission.text)??0,'customer':customer.text,'created':DateTime.now().toIso8601String()});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Transaction saved')));}@override Widget build(BuildContext c){if(widget.serviceOnly!=null)svc=widget.serviceOnly!;return ListView(padding:const EdgeInsets.all(12),children:[Text(widget.serviceOnly??'Mobile Services Ledger',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),DropdownButtonFormField(value:svc,items:services.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>setState(()=>svc=v!),decoration:const InputDecoration(labelText:'Network / Service')),TextField(controller:amount,decoration:const InputDecoration(labelText:'Amount Rs'),keyboardType:TextInputType.number),TextField(controller:commission,decoration:const InputDecoration(labelText:'Commission Rs'),keyboardType:TextInputType.number),TextField(controller:customer,decoration:const InputDecoration(labelText:'Customer')),FilledButton(onPressed:save,child:const Text('Save Transaction'))]);}}
class RsoPage extends StatefulWidget{const RsoPage({super.key});@override State<RsoPage> createState()=>_RsoPageState();}
class _RsoPageState extends State<RsoPage>{String company='Jazz';final opening=TextEditingController(text:'0'),load=TextEditingController(text:'0'),sale=TextEditingController(text:'0'),remaining=TextEditingController(text:'0'),transfer=TextEditingController(text:'0'),katta=TextEditingController(text:'0'),note=TextEditingController();final companies=['Jazz','Zong','Telenor','Ufone','Udhaar App','One Load','Cash'];double v(TextEditingController x)=>double.tryParse(x.text)??0;Future<void>save()async{await DB.i.db.insert('rso_daily',{'ledger_date':DateFormat('yyyy-MM-dd').format(DateTime.now()),'company':company,'opening':v(opening),'load2':v(load),'sale':v(sale),'rso_remaining':v(remaining),'transfer':v(transfer),'katta':v(katta),'note':note.text});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('E Zero record saved')));}@override Widget build(BuildContext c){final total=v(opening)+v(load),rem=total-v(sale),ledger=v(remaining)-v(transfer)-v(katta);return ListView(padding:const EdgeInsets.all(12),children:[const Text('E Zero / RSO Ledger',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),DropdownButtonFormField(value:company,items:companies.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>setState(()=>company=v!),decoration:const InputDecoration(labelText:'Company')),for(final x in [('Opening Balance',opening),('2 Day Load',load),('Sale',sale),('RSO Total Remaining',remaining),('Today Transfer',transfer),('RSO Katta',katta),('Note',note)])TextField(controller:x.$2,decoration:InputDecoration(labelText:x.$1),keyboardType:x.$1=='Note'?TextInputType.text:TextInputType.number),Card(child:Padding(padding:const EdgeInsets.all(12),child:Text('Total Balance = Rs. ${fmt.format(total)}\\nRemaining = Rs. ${fmt.format(rem)}\\nRemaining Ledger = Rs. ${fmt.format(ledger)}',style:const TextStyle(fontWeight:FontWeight.bold)))),FilledButton(onPressed:save,child:const Text('Save Daily Record'))]);}}
class CustomerPage extends StatelessWidget{const CustomerPage({super.key});@override Widget build(BuildContext c)=>const EntryPage('Customer Directory','customers',['name','phone','address']);}
class PaymentPage extends StatelessWidget{const PaymentPage({super.key});@override Widget build(BuildContext c)=>const EntryPage('Payments / Receipts','payments',['party','kind','amount','note','created']);}
class ExpensePage extends StatelessWidget{const ExpensePage({super.key});@override Widget build(BuildContext c)=>const EntryPage('Expenses','expenses',['category','amount','note','created']);}
class ReportPage extends StatelessWidget{const ReportPage({super.key});Future<void>pdf()async{final items=await DB.i.all('items'),sales=await DB.i.all('sales');final doc=pw.Document();doc.addPage(pw.MultiPage(build:(_)=>[pw.Header(level:0,child:pw.Text('EasyLoad Shop Manager Report')),pw.Header(level:1,child:pw.Text('Stock')),pw.TableHelper.fromTextArray(data:[['Name','Qty','Buy','Sell'],...items.map((r)=>[r['name'],r['qty'],r['buy'],r['sell']])]),pw.Header(level:1,child:pw.Text('Sales')),pw.TableHelper.fromTextArray(data:[['Item','Qty','Total','Paid'],...sales.map((r)=>[r['item_name'],r['qty'],r['total'],r['paid']])])]));await Printing.layoutPdf(onLayout:(_)=>doc.save());}Future<void>backup()async{final dir=await getExternalStorageDirectory();await File('${dir!.path}/easyload_backup.db').writeAsBytes(await File(DB.i.db.path).readAsBytes());} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Reports & Backup',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),FilledButton(onPressed:pdf,child:const Text('Create PDF Report')),FilledButton(onPressed:backup,child:const Text('Create Database Backup')),const Text('Backup is saved in the app external files folder. Restore/import workflow is not yet implemented.')]);}


class SupplierPage extends StatefulWidget {const SupplierPage({super.key});@override State<SupplierPage> createState()=>_SupplierPageState();}
class _SupplierPageState extends State<SupplierPage>{List<Map<String,Object?>> rows=[];@override void initState(){super.initState();load();}Future<void>load()async{rows=await DB.i.db.rawQuery("SELECT supplier,COUNT(*) AS entries,COALESCE(SUM(total),0) AS total,MAX(created) AS last_date FROM purchases WHERE COALESCE(supplier,'')<>'' GROUP BY supplier ORDER BY supplier");if(mounted)setState((){});}@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(14),children:[const Text('Supplier Ledger',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const Text('Suppliers are recorded from the Purchase page.'),FilledButton(onPressed:load,child:const Text('Refresh Suppliers')),...rows.map((r)=>Card(child:ListTile(title:Text('${r['supplier']}'),subtitle:Text('${r['entries']} purchases • Last: ${r['last_date']??''}'),trailing:Text('Rs. ${fmt.format(r['total']??0)}'))))]);}

class StockAdjustmentPage extends StatefulWidget {const StockAdjustmentPage({super.key});@override State<StockAdjustmentPage> createState()=>_StockAdjustmentPageState();}
class _StockAdjustmentPageState extends State<StockAdjustmentPage>{final item=TextEditingController(),qty=TextEditingController(text:'1'),reason=TextEditingController();List<Map<String,Object?>> rows=[];@override void initState(){super.initState();load();}Future<void>load()async{rows=await DB.i.all('adjustments');if(mounted)setState((){});}Future<void>save()async{final q=double.tryParse(qty.text)??0;if(item.text.trim().isEmpty||q<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter item and valid quantity')));return;}final matches=await DB.i.db.query('items',where:'LOWER(name)=LOWER(?)',whereArgs:[item.text.trim()],limit:1);if(matches.isNotEmpty){final stock=(matches.first['qty'] as num?)?.toDouble()??0;if(q>stock){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Loss quantity exceeds available stock')));return;}await DB.i.db.update('items',{'qty':stock-q},where:'id=?',whereArgs:[matches.first['id']]);}await DB.i.db.insert('adjustments',{'item_name':item.text.trim(),'qty':q,'reason':reason.text.trim(),'created':DateTime.now().toIso8601String()});item.clear();qty.text='1';reason.clear();await load();} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(14),children:[const Text('Damaged / Lost Stock',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),TextField(controller:item,decoration:const InputDecoration(labelText:'Item name')),TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantity lost')),TextField(controller:reason,decoration:const InputDecoration(labelText:'Reason')),FilledButton(onPressed:save,child:const Text('Record Stock Loss')),...rows.map((r)=>Card(child:ListTile(title:Text('${r['item_name']} • Qty ${r['qty']}'),subtitle:Text('${r['reason']??''} • ${r['created']??''}'))))]);}

class ProfitLossPage extends StatefulWidget {const ProfitLossPage({super.key});@override State<ProfitLossPage> createState()=>_ProfitLossPageState();}
class _ProfitLossPageState extends State<ProfitLossPage>{double sales=0,cost=0,expenses=0,loss=0;@override void initState(){super.initState();load();}Future<void>load()async{final now=DateTime.now();final start=DateTime(now.year,now.month,1).toIso8601String();final end=now.add(const Duration(days:1)).toIso8601String();final s=await DB.i.db.rawQuery('SELECT COALESCE(SUM(total),0) x FROM sales WHERE created>=? AND created<?',[start,end]);final p=await DB.i.db.rawQuery('SELECT COALESCE(SUM(total),0) x FROM purchases WHERE created>=? AND created<?',[start,end]);final e=await DB.i.db.rawQuery('SELECT COALESCE(SUM(amount),0) x FROM expenses WHERE created>=? AND created<?',[start,end]);final a=await DB.i.db.rawQuery('SELECT COALESCE(SUM(a.qty*COALESCE(i.buy,0)),0) x FROM adjustments a LEFT JOIN items i ON LOWER(i.name)=LOWER(a.item_name) WHERE a.created>=? AND a.created<?',[start,end]);sales=(s.first['x'] as num).toDouble();cost=(p.first['x'] as num).toDouble();expenses=(e.first['x'] as num).toDouble();loss=(a.first['x'] as num).toDouble();if(mounted)setState((){});} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Monthly Profit & Loss (Estimate)',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),Card(child:Column(children:[ListTile(title:const Text('Sales value'),trailing:Text('Rs. ${fmt.format(sales)}')),ListTile(title:const Text('Purchase value (reference)'),trailing:Text('Rs. ${fmt.format(cost)}')),ListTile(title:const Text('Expenses'),trailing:Text('Rs. ${fmt.format(expenses)}')),ListTile(title:const Text('Stock loss estimate'),trailing:Text('Rs. ${fmt.format(loss)}')),const Divider(),ListTile(title:const Text('Estimated net (sales − purchases − expenses − loss)',style:TextStyle(fontWeight:FontWeight.bold)),trailing:Text('Rs. ${fmt.format(sales-cost-expenses-loss)}',style:const TextStyle(fontWeight:FontWeight.bold))) ])),const Text('Note: this is a simple estimate, not item-level gross profit. The desktop program uses unit cost per sold item; the Android migration still needs full cost-of-goods tracking.'),FilledButton(onPressed:load,child:const Text('Refresh'))]);}

class BackupRestorePage extends StatefulWidget {const BackupRestorePage({super.key});@override State<BackupRestorePage> createState()=>_BackupRestorePageState();}
class _BackupRestorePageState extends State<BackupRestorePage>{String message='';Future<void>backup()async{final path=await FilePicker.platform.saveFile(dialogTitle:'Save EasyLoad backup',fileName:'easyload_backup.db',type:FileType.custom,allowedExtensions:['db']);if(path==null)return;await File(DB.i.db.path).copy(path);if(mounted)setState(()=>message='Backup saved: $path');}Future<void>restore()async{final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['db']);if(result==null||result.files.single.path==null)return;final source=File(result.files.single.path!);final check=await openDatabase(source.path,readOnly:true);final tables=await check.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='items'");await check.close();if(tables.isEmpty){if(mounted)setState(()=>message='Selected file is not an EasyLoad database.');return;}await DB.i.db.close();await source.copy(DB.i.db.path);await DB.i.open();if(mounted)setState(()=>message='Backup restored. Please restart the app to refresh all screens.');} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Backup & Restore',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const Text('Create a copy of all local shop records or restore a previous EasyLoad database.'),const SizedBox(height:12),FilledButton.icon(onPressed:backup,icon:const Icon(Icons.backup),label:const Text('Create Backup')),OutlinedButton.icon(onPressed:restore,icon:const Icon(Icons.restore),label:const Text('Restore Backup')),if(message.isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(message)),const Text('Always create a fresh backup before restoring. Restoring replaces the current local database.')]);}


class ScannerPage extends StatefulWidget {const ScannerPage({super.key});@override State<ScannerPage> createState()=>_ScannerPageState();}
class _ScannerPageState extends State<ScannerPage>{String code='';Map<String,Object?>? found;bool locked=false;Future<void>lookup(String value)async{if(value.isEmpty)return;final rows=await DB.i.db.query('items',where:'barcode=?',whereArgs:[value],limit:1);if(mounted)setState((){code=value;found=rows.isEmpty?null:rows.first;locked=true;});} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[const Text('QR Code / Barcode Scanner',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),SizedBox(height:300,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:MobileScanner(onDetect:(capture){if(locked)return;final value=capture.barcodes.isNotEmpty?capture.barcodes.first.rawValue:null;if(value!=null)lookup(value);}))),const SizedBox(height:12),Text('Scanned code: ${code.isEmpty?'—':code}'),if(code.isNotEmpty)FilledButton(onPressed:()=>setState(()=>locked=false),child:const Text('Scan Next Code')),if(code.isNotEmpty)Card(child:ListTile(title:Text(found==null?'Product not found': '${found!['name']}'),subtitle:Text(found==null?'No matching barcode is saved in Products / Items':'Stock: ${found!['qty']} • Buy: ${found!['buy']} • Sell: ${found!['sell']}'))),const Text('A USB barcode scanner can also be used by typing/scanning its code into a barcode field when that field is available.')]);}

class SubscriptionGate extends StatefulWidget {
 const SubscriptionGate({super.key});
 @override State<SubscriptionGate> createState()=>_SubscriptionGateState();
}
class _SubscriptionGateState extends State<SubscriptionGate> {
 bool loading=true,allowed=false; int days=0;
 @override void initState(){super.initState();check();}
 Future<void> check() async {
  final active=await DB.i.hasActiveSubscription();
  final left=await DB.i.daysLeftInTrial();
  if(mounted)setState(() { loading=false; allowed=active||left>0; days=left; });
 }
 @override Widget build(BuildContext c) {
  if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
  if(allowed)return const Login();
  return SubscriptionPage(onActivated:check,expired:true);
 }
}
class SubscriptionPage extends StatefulWidget {
 final VoidCallback? onActivated; final bool expired;
 const SubscriptionPage({super.key,this.onActivated,this.expired=false});
 @override State<SubscriptionPage> createState()=>_SubscriptionPageState();
}
class _SubscriptionPageState extends State<SubscriptionPage> {
 String plan='Monthly',method='JazzCash'; final email=TextEditingController(),payer=TextEditingController(),phone=TextEditingController(),txn=TextEditingController();
 String info=''; int days=0; bool active=false; String until='';
 @override void initState(){super.initState();load();}
 Future<void> load() async {
  days=await DB.i.daysLeftInTrial(); active=await DB.i.hasActiveSubscription();
  until=await DB.i.setting('subscription_until','');
  email.text=await DB.i.setting('account_email','');
  if(mounted)setState((){});
 }
 double get price=>plan=='Monthly'?500:5000;
 Future<void> submit() async {
  if(email.text.trim().isEmpty||!email.text.contains('@')||payer.text.trim().isEmpty||phone.text.trim().isEmpty||txn.text.trim().isEmpty){
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter email, payer name, phone and transaction/reference ID.')));return;
  }
  await DB.i.setSetting('account_email',email.text.trim());
  await DB.i.db.insert('payment_requests',{'email':email.text.trim(),'plan':plan,'amount':price,'method':method,'payer_name':payer.text.trim(),'payer_phone':phone.text.trim(),'transaction_id':txn.text.trim(),'status':'Pending','created':DateTime.now().toIso8601String()});
  if(mounted) {
   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Payment request saved as Pending. Admin must verify the transaction before activation.')));
   txn.clear(); setState((){});
  }
 }
 Future<void> approveLatest() async {
  final pin=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Admin approval'),content:TextField(controller:pin,obscureText:true,decoration:const InputDecoration(labelText:'Admin PIN')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Verify'))]));
  if(ok!=true)return;
  final saved=await DB.i.setting('pin','1234');
  if(pin.text!=saved){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Incorrect admin PIN')));return;}
  final requests=await DB.i.db.query('payment_requests',where:'status=?',whereArgs:['Pending'],orderBy:'id DESC',limit:1);
  if(requests.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No pending payment request found')));return;}
  final r=requests.first;
  final verified=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
   title:const Text('Verify manual payment'),
   content:Text('Email: ${r['email']}\nPayer: ${r['payer_name']}\nPhone: ${r['payer_phone']}\nMethod: ${r['method']}\nAmount: PKR ${r['amount']}\nTransaction ID: ${r['transaction_id']}\n\nApprove only after checking the payment in your JazzCash/Easypaisa account.'),
   actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Payment verified — Approve'))],
  ));
  if(verified!=true)return;
  final months=r['plan']=='Yearly'?12:1;
  final now=DateTime.now(); final base=DateTime.tryParse(await DB.i.setting('subscription_until',''))??now;
  final start=base.isAfter(now)?base:now;
  final targetMonth=DateTime(start.year,start.month+months,1);
  final lastDay=DateTime(targetMonth.year,targetMonth.month+1,0).day;
  final expiry=DateTime(targetMonth.year,targetMonth.month,start.day.clamp(1,lastDay).toInt(),start.hour,start.minute);
  await DB.i.setSetting('subscription_status','active');
  await DB.i.setSetting('subscription_until',expiry.toIso8601String());
  await DB.i.db.update('payment_requests',{'status':'Approved'},where:'id=?',whereArgs:[r['id']]);
  if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Subscription activated until ${DateFormat('dd MMM yyyy').format(expiry)}')));setState((){});widget.onActivated?.call();}
 }
 @override Widget build(BuildContext c)=>Scaffold(
  appBar:AppBar(title:const Text('EasyLoad Subscription'),backgroundColor:navy,foregroundColor:Colors.white),
  body:ListView(padding:const EdgeInsets.all(16),children:[
   const Icon(Icons.workspace_premium,color:red,size:54),
   const Text('EasyLoad Shop Manager',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
   const SizedBox(height:12),
   Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
    Text(active?'Subscription Active':(days>0?'7-Day Free Trial':'Free Trial Expired'),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
    const SizedBox(height:6),
    Text(active?'Valid until: $until':(days>0?'$days day(s) remaining':'Choose a plan and submit your manual payment details.')),
   ]))),
   const SizedBox(height:12),
   const Text('Choose Subscription Plan',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
   RadioListTile<String>(value:'Monthly',groupValue:plan,title:const Text('Monthly — PKR 500'),onChanged:(v)=>setState(()=>plan=v!)),
   RadioListTile<String>(value:'Yearly',groupValue:plan,title:const Text('Yearly — PKR 5,000'),onChanged:(v)=>setState(()=>plan=v!)),
   const Divider(),
   const Text('Manual Payment',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
   DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'Payment method'),items:const [DropdownMenuItem(value:'JazzCash',child:Text('JazzCash')),DropdownMenuItem(value:'Easypaisa',child:Text('Easypaisa'))],onChanged:(v)=>setState(()=>method=v!)),
   const SizedBox(height:8),
   FutureBuilder<String>(future:DB.i.setting(method.toLowerCase()+'_title',''),builder:(c,s)=>FutureBuilder<String>(future:DB.i.setting(method.toLowerCase()+'_number',''),builder:(c,n)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Text((s.data??'').isEmpty&&(n.data??'').isEmpty?'Payment account details have not been configured by the administrator yet.': '${s.data??''}\n${n.data??''}'))))),
   Text('Amount to pay: PKR ${price.toStringAsFixed(0)}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
   TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Account email')),
   TextField(controller:payer,decoration:const InputDecoration(labelText:'Payer name')),
   TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Payer mobile number')),
   TextField(controller:txn,decoration:const InputDecoration(labelText:'JazzCash / Easypaisa transaction ID')),
   const SizedBox(height:10),
   FilledButton(onPressed:submit,child:const Text('Submit Payment Request')),
   OutlinedButton(onPressed:approveLatest,child:const Text('Admin: Verify & Activate Latest Payment')),
   const Text('Manual payments are not automatically verified. An administrator must check the transaction receipt before approving.'),
   if(widget.expired)OutlinedButton(onPressed:()=>Navigator.pushReplacement(c,MaterialPageRoute(builder:(_)=>const Login())),child:const Text('Back to Login')),
  ])
 );
}


class SettingsPage extends StatefulWidget{const SettingsPage({super.key});@override State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage>{
 final shop=TextEditingController(),user=TextEditingController(),pin=TextEditingController(),jt=TextEditingController(),jn=TextEditingController(),et=TextEditingController(),en=TextEditingController();
 @override void initState(){super.initState();load();}
 Future<void>load()async{
  for(final x in [('shop',shop),('user',user),('pin',pin),('jazzcash_title',jt),('jazzcash_number',jn),('easypaisa_title',et),('easypaisa_number',en)]){x.$2.text=await DB.i.setting(x.$1,'');}
  if(mounted)setState((){});
 }
 Future<void>save()async{
  for(final x in [('shop',shop.text),('user',user.text),('pin',pin.text),('jazzcash_title',jt.text),('jazzcash_number',jn.text),('easypaisa_title',et.text),('easypaisa_number',en.text)]){await DB.i.setSetting(x.$1,x.$2);}
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Settings saved')));
 }
 @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Settings',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  TextField(controller:shop,decoration:const InputDecoration(labelText:'Shop name')),
  TextField(controller:user,decoration:const InputDecoration(labelText:'Admin username')),
  TextField(controller:pin,decoration:const InputDecoration(labelText:'Admin password / PIN')),
  const SizedBox(height:16),const Text('Manual Subscription Payment Accounts',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
  TextField(controller:jt,decoration:const InputDecoration(labelText:'JazzCash account title')),
  TextField(controller:jn,decoration:const InputDecoration(labelText:'JazzCash account number')),
  TextField(controller:et,decoration:const InputDecoration(labelText:'Easypaisa account title')),
  TextField(controller:en,decoration:const InputDecoration(labelText:'Easypaisa account number')),
  const SizedBox(height:12),
  FilledButton(onPressed:save,child:const Text('Save Settings')),
  OutlinedButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const SubscriptionPage())),child:const Text('Open Subscription & Payment Requests')),
  const Text('Subscription: 7-day trial • Monthly PKR 500 • Yearly PKR 5,000 • Manual JazzCash / Easypaisa'),
  const Text('Developer: Muhammad Ilyas')
 ]);
}
