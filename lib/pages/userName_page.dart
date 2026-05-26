import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';

class UserNamePage extends StatefulWidget {
  final int optionIndex; // UI index 1-5

  const UserNamePage({super.key, required this.optionIndex});

  @override
  State<UserNamePage> createState() => _UserNamePageState();
}

class _UserNamePageState extends State<UserNamePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isSaving = false;

  static const int _maxTitle = 30;
  static const int _maxDesc = 50;

  @override
  void initState() {
    super.initState();
    final bt = Provider.of<BluetoothService>(context, listen: false);
    final btIndex = widget.optionIndex - 1;
    if (bt.optionNames.containsKey(btIndex)) {
      _titleController.text = bt.optionNames[btIndex]!;
    }
    _descController.text = bt.getOptionDescription(btIndex);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bt = Provider.of<BluetoothService>(context, listen: false);
      final btIndex = widget.optionIndex - 1;

      await bt.sendOptionName(btIndex, title);
      await bt.saveOptionDescription(btIndex, _descController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully'), duration: Duration(seconds: 1)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildLabel('Edit Title:'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      maxLength: _maxTitle,
                      hint: 'Enter title',
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Edit Description:'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descController,
                      maxLength: _maxDesc,
                      hint: 'Enter description',
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Update Preset Image:'),
                    const SizedBox(height: 8),
                    _buildPickImageButton(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'Edit Presets',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required int maxLength,
    required String hint,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: controller,
              maxLength: maxLength,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  const SizedBox.shrink(),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFF512F), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.text.length}/$maxLength',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPickImageButton() {
    return GestureDetector(
      onTap: () {
        // TODO: implement image pick & upload
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF512F), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_outlined, color: Color(0xFFFF512F), size: 18),
            SizedBox(width: 8),
            Text(
              'Pick Image & Upload',
              style: TextStyle(
                color: Color(0xFFFF512F),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _onSave,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Text(
                  'SAVE SETTING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
        ),
      ),
    );
  }
}
