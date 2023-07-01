import 'package:flutter/material.dart';
import 'package:fuel_efficiency_record/constants.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/refuel_entry.dart';
import '../utils/int_validator.dart';

class VehicleNameDialog extends StatefulWidget {
  const VehicleNameDialog({
    super.key,
    this.currentName,
  });

  final String? currentName;

  @override
  State<StatefulWidget> createState() => _VehicleNameDialogState();
}

class _VehicleNameDialogState extends State<VehicleNameDialog> {
  late GlobalKey<FormState> _vehicleNameGlobalKey;
  late GlobalKey<FormState> _odometerGlobalKey;
  late TextEditingController _vehicleNameTextFieldController;
  late TextEditingController _odometerTextFieldController;

  List<String>? _vehicleNames;
  bool _isValidName = false;
  bool _isValidOdometer = false;

  @override
  void initState() {
    super.initState();

    _vehicleNameGlobalKey = GlobalKey();
    _odometerGlobalKey = GlobalKey();
    _vehicleNameTextFieldController = TextEditingController();
    _odometerTextFieldController = TextEditingController();

    if (widget.currentName != null) {
      _vehicleNameTextFieldController.text = widget.currentName!;
    }

    Future(() async {
      final db = await openDatabase(
          join(await getDatabasesPath(), refuelHistoryDBName));
      final vehiclesRes = await db.query(vehicleNameTable);
      setState(() {
        _vehicleNames =
            vehiclesRes.map((row) => row['name'] as String).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.currentName == null
          ? const Text('車両を追加')
          : const Text('車両名を変更'),
      content: _vehicleNames == null
          ? const Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(
                  width: 32.0,
                  height: 32.0,
                  child: CircularProgressIndicator(),
                )
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: _vehicleNameGlobalKey,
                  child: TextFormField(
                    controller: _vehicleNameTextFieldController,
                    validator: (input) {
                      if (input == null || input.isEmpty) {
                        setState(() {
                          _isValidName = true;
                        });
                        return null;
                      }

                      if (widget.currentName == input) {
                        setState(() {
                          _isValidName = false;
                        });
                        return '同じ車両名です';
                      }

                      if (_vehicleNames!.contains(input)) {
                        setState(() {
                          _isValidName = false;
                        });
                        return '同名の車両が既に存在します';
                      }

                      setState(() {
                        _isValidName = true;
                      });
                      return null;
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '車両名',
                    ),
                    onChanged: (input) {
                      _vehicleNameGlobalKey.currentState!.validate();
                    },
                  ),
                ),
                if (widget.currentName == null)
                  const SizedBox(
                    width: 0,
                    height: 16,
                  ),
                if (widget.currentName == null)
                  Form(
                    key: _odometerGlobalKey,
                    child: TextFormField(
                      controller: _odometerTextFieldController,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '現在の走行距離 [km]'),
                      validator: (input) {
                        final intValidation = intFormValidator(input);
                        setState(() {
                          _isValidOdometer = intValidation == null;
                        });
                        return intValidation;
                      },
                      onChanged: (input) {
                        _odometerGlobalKey.currentState!.validate();
                      },
                    ),
                  ),
              ],
            ),
      actions: [
        TextButton(
          child: const Text('キャンセル'),
          onPressed: () {
            _vehicleNameTextFieldController.text = '';
            _odometerTextFieldController.text = '';
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          onPressed: (_vehicleNameTextFieldController.text.isEmpty ||
                      !_isValidName) &&
                  (widget.currentName != null ||
                      _odometerTextFieldController.text.isEmpty ||
                      _isValidOdometer)
              ? null
              : () {
                  Future(() async {
                    final db = await openDatabase(
                        join(await getDatabasesPath(), refuelHistoryDBName));
                    if (widget.currentName != null) {
                      await db.execute(
                          'ALTER TABLE ${widget.currentName} RENAME TO ${_vehicleNameTextFieldController.text};');
                      await db.delete(vehicleNameTable,
                          where: 'name = "${widget.currentName}"');
                    }

                    await db.insert(
                      vehicleNameTable,
                      {
                        'name': _vehicleNameTextFieldController.text,
                      },
                      conflictAlgorithm: ConflictAlgorithm.fail,
                    );

                    if (widget.currentName != null) {
                      return 0;
                    }

                    await db.execute('CREATE TABLE '
                        '${_vehicleNameTextFieldController.text}'
                        '(${RefuelEntry.timestampFieldName} INTEGER PRIMARY KEY,'
                        '${RefuelEntry.dateTimeFieldName} TEXT,'
                        '${RefuelEntry.refuelAmountFieldName} REAL,'
                        '${RefuelEntry.unitPriceFieldName} INTEGER,'
                        '${RefuelEntry.totalPriceFieldName} INTEGER,'
                        '${RefuelEntry.odometerFieldName} INTEGER,'
                        '${RefuelEntry.isFullTankFieldName} INTEGER)');
                    final refuelEntry = RefuelEntry(
                      dateTime: DateTime.now(),
                      refuelAmount: 0,
                      unitPrice: 0,
                      // 入力時にバリデーションしてるので必ず整数です ↓
                      odometer:
                          int.tryParse(_odometerTextFieldController.text)!,
                      totalPrice: 0,
                      isFullTank: true,
                    );
                    await db.insert(
                      _vehicleNameTextFieldController.text,
                      refuelEntry.toMap(),
                      conflictAlgorithm: ConflictAlgorithm.fail,
                    );
                    return 0;
                  }).then((_) {
                    Navigator.of(context).pop();
                  });

                  // Navigator.of(context).pop();
                },
          child:
              widget.currentName == null ? const Text('追加') : const Text('変更'),
        )
      ],
    );
  }
}
