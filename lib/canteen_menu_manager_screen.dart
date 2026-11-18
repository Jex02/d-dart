import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'data/campus_menu_catalog.dart';
import 'login.dart';
import 'models/campus_location.dart';
import 'models/cart_item.dart';
import 'models/user_profile.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'widgets/responsive_shell.dart';

/// Standalone dashboard for Canteen-Scoped Admins (locked to [assignedCanteen]).
class CanteenMenuManagerScreen extends StatelessWidget {
  final String assignedCanteen;
  final UserProfile? profile;

  const CanteenMenuManagerScreen({
    super.key,
    required this.assignedCanteen,
    this.profile,
  });

  Future<void> _handleSignOut(BuildContext context) async {
    await SupabaseService().signOut();
    DutyLockService.reset();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDartTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: DDartTheme.primaryMaroon,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$assignedCanteen Manager',
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
            Text(
              profile?.fullName.isNotEmpty == true
                  ? '${profile!.fullName} • Canteen Admin'
                  : 'Canteen Menu Admin',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(iconColor: Colors.white, iconSize: 21),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CanteenMenuManagerBody(lockedCanteen: assignedCanteen),
        ),
      ),
    );
  }
}

/// Reusable Menu CRUD view used by both Canteen Admins (with [lockedCanteen])
/// and Super Admins inside [AdminDashboardScreen] (with [lockedCanteen] == null).
class CanteenMenuManagerBody extends StatefulWidget {
  final String? lockedCanteen;

  const CanteenMenuManagerBody({
    super.key,
    this.lockedCanteen,
  });

  @override
  State<CanteenMenuManagerBody> createState() => _CanteenMenuManagerBodyState();
}

class _CanteenMenuManagerBodyState extends State<CanteenMenuManagerBody> {
  final _service = SupabaseService();
  final _searchCtrl = TextEditingController();
  final _picker = ImagePicker();

  List<CanteenMenuItem> _items = [];
  bool _loading = true;
  late String _selectedCanteenFilter;
  String _selectedCategoryFilter = 'All';

  bool get _isLocked =>
      widget.lockedCanteen != null && widget.lockedCanteen!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedCanteenFilter = _isLocked ? widget.lockedCanteen!.trim() : 'All';
    _loadMenuItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenuItems() async {
    setState(() => _loading = true);
    try {
      final fetched = await _service.fetchManageableMenuItems(
        canteen: _isLocked ? widget.lockedCanteen : null,
      );
      if (mounted) {
        setState(() {
          _items = fetched;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Failed to load menu items: $e', isError: true);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? Colors.redAccent : Colors.green.shade700,
          content: Text(message),
        ),
      );
  }

  List<CanteenMenuItem> get _filteredItems {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _items.where((item) {
      final matchesCanteen = _selectedCanteenFilter == 'All' ||
          item.canteen.toLowerCase() == _selectedCanteenFilter.toLowerCase();
      final matchesCategory = _selectedCategoryFilter == 'All' ||
          CampusMenuCatalog.matchesCategory(item.category, _selectedCategoryFilter);
      final matchesQuery = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.unitDescription.toLowerCase().contains(q);
      return matchesCanteen && matchesCategory && matchesQuery;
    }).toList();
  }

  Future<void> _openItemEditor({CanteenMenuItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final descCtrl = TextEditingController(text: existing?.unitDescription ?? '');
    final imageUrlCtrl = TextEditingController(text: existing?.imageUrl ?? '');

    String selectedCanteen = _isLocked
        ? widget.lockedCanteen!.trim()
        : (existing?.canteen ??
            (_selectedCanteenFilter != 'All'
                ? _selectedCanteenFilter
                : CampusLocation.officialCanteens.first));

    String selectedCategory = CampusMenuCatalog.categories.contains(existing?.category)
        ? existing!.category
        : CampusMenuCatalog.categories.first;
    bool isAvailable = existing?.isAvailable ?? true;
    bool isUploadingPhoto = false;
    bool isSaving = false;
    String? formError;

    final saved = await showDialog<CanteenMenuItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickAndUploadPhoto() async {
            try {
              final XFile? picked = await _picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 80,
              );
              if (picked == null) return;
              setDialogState(() {
                isUploadingPhoto = true;
                formError = null;
              });
              final bytes = await picked.readAsBytes();
              final publicUrl = await _service.uploadMenuItemImage(
                canteen: selectedCanteen,
                fileName: picked.name,
                bytes: bytes,
              );
              setDialogState(() {
                imageUrlCtrl.text = publicUrl;
                isUploadingPhoto = false;
              });
            } catch (e) {
              setDialogState(() {
                isUploadingPhoto = false;
                formError = 'Photo upload failed: $e';
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  existing == null ? Icons.add_circle_outline : Icons.edit_outlined,
                  color: DDartTheme.accentText(ctx),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    existing == null ? 'Add Food Item' : 'Edit Food Item',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: DDartTheme.maroonTint(ctx),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: DDartTheme.accentText(ctx).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16, color: DDartTheme.accentText(ctx)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Assigned Canteen: $selectedCanteen',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: DDartTheme.accentText(ctx),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: CampusLocation.officialCanteens.contains(selectedCanteen)
                            ? selectedCanteen
                            : CampusLocation.officialCanteens.first,
                        decoration: const InputDecoration(
                          labelText: 'Canteen',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: CampusLocation.officialCanteens
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCanteen = val);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g. Pork Sisig w/ Rice',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: CampusMenuCatalog.categories
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price (₱)',
                        hintText: 'e.g. 55.00',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Serving Size',
                        hintText: 'e.g. With garlic rice, egg & gravy',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imageUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Photo URL (optional)',
                              hintText: 'Paste image URL or upload',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: isUploadingPhoto ? null : pickAndUploadPhoto,
                          icon: isUploadingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_library_outlined, size: 17),
                          label: const Text('Upload'),
                        ),
                      ],
                    ),
                    if (imageUrlCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrlCtrl.text.trim(),
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 60,
                            color: DDartTheme.cardSubtle(ctx),
                            alignment: Alignment.center,
                            child: const Text(
                              'Image preview unavailable',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Available for Ordering',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isAvailable
                            ? 'Visible to customers right now'
                            : 'Hidden (marked Sold Out)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      activeThumbColor: DDartTheme.brightGold,
                      activeTrackColor: DDartTheme.primaryMaroon,
                      value: isAvailable,
                      onChanged: (v) => setDialogState(() => isAvailable = v),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        formError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DDartTheme.primaryMaroon,
                  foregroundColor: Colors.white,
                ),
                onPressed: (isSaving || isUploadingPhoto)
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final price = double.tryParse(priceCtrl.text.trim());
                        if (name.length < 2) {
                          setDialogState(() => formError = 'Enter an item name (min 2 chars).');
                          return;
                        }
                        if (price == null || price <= 0) {
                          setDialogState(() => formError = 'Enter a valid price greater than 0.');
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          formError = null;
                        });

                        // Preserve additional canteens only if Super Admin is editing an existing multi-canteen item;
                        // for Canteen Admins or newly created items, scope cleanly to the owning canteen.
                        final canteens = (_isLocked || existing == null)
                            ? <String>[selectedCanteen]
                            : (existing.availableCanteens.contains(selectedCanteen)
                                ? existing.availableCanteens
                                : <String>[selectedCanteen]);

                        final candidate = CanteenMenuItem(
                          id: existing?.id ?? '',
                          name: name,
                          canteen: selectedCanteen,
                          category: selectedCategory,
                          price: price,
                          unitDescription: descCtrl.text.trim(),
                          imageUrl: imageUrlCtrl.text.trim().isEmpty
                              ? null
                              : imageUrlCtrl.text.trim(),
                          isAvailable: isAvailable,
                          availableCanteens: canteens,
                        );

                        try {
                          final upserted = await _service.upsertMenuItem(candidate);
                          if (ctx.mounted) Navigator.pop(ctx, upserted);
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            formError = 'Could not save item: $e';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(existing == null ? 'Add Item' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
    imageUrlCtrl.dispose();

    if (saved != null) {
      await _loadMenuItems();
      _showSnack(
        existing == null
            ? 'Added "${saved.name}" to ${saved.canteen}!'
            : 'Updated "${saved.name}".',
      );
    }
  }

  Future<void> _confirmDelete(CanteenMenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Food Item?'),
        content: Text(
          'Delete "${item.name}" from ${item.canteen}? Customers will no longer see it on the menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteMenuItem(item.id);
      await _loadMenuItems();
      _showSnack('Deleted "${item.name}".');
    } catch (e) {
      _showSnack('Failed to delete item: $e', isError: true);
    }
  }

  Future<void> _toggleAvailability(CanteenMenuItem item, bool newVal) async {
    try {
      await _service.toggleMenuItemAvailability(item.id, newVal);
      setState(() {
        final idx = _items.indexWhere((i) => i.id == item.id);
        if (idx != -1) {
          _items[idx] = item.copyWith(isAvailable: newVal);
        }
      });
    } catch (e) {
      _showSnack('Could not update availability: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);
    final accent = DDartTheme.accentText(context);

    return Column(
      children: [
        // Top Scope & Filter Header
        Container(
          color: DDartTheme.surface(context),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: DDartTheme.maroonTint(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLocked ? Icons.storefront : Icons.restaurant_menu,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLocked
                                  ? 'Scoped to ${widget.lockedCanteen} (${filtered.length} items)'
                                  : 'All Canteens Menu (${filtered.length} items)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _openItemEditor(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DDartTheme.primaryMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Item',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: DDartTheme.fieldFill(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(Icons.search, size: 18, color: textSecondary),
                    hintText: 'Search menu items...',
                    hintStyle: TextStyle(fontSize: 12, color: DDartTheme.textMuted(context)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Canteen Filter Chips (Super Admin only)
              if (!_isLocked) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'All',
                      ...CampusLocation.officialCanteens,
                    ].map((canteen) {
                      final selected = _selectedCanteenFilter == canteen;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            canteen == 'All' ? 'All Canteens' : canteen,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? Colors.white : textPrimary,
                            ),
                          ),
                          selected: selected,
                          selectedColor: DDartTheme.primaryMaroon,
                          backgroundColor: DDartTheme.cardSubtle(context),
                          onSelected: (v) {
                            if (v) setState(() => _selectedCanteenFilter = canteen);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    ...CampusMenuCatalog.categories,
                  ].map((cat) {
                    final selected = _selectedCategoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat == 'All' ? 'All Categories' : cat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? accent : textPrimary,
                          ),
                        ),
                        selected: selected,
                        selectedColor: accent.withValues(alpha: 0.16),
                        backgroundColor: DDartTheme.cardSubtle(context),
                        onSelected: (v) {
                          if (v) setState(() => _selectedCategoryFilter = cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: DDartTheme.divider(context)),

        // Menu Items List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: DDartTheme.primaryMaroon),
                )
              : RefreshIndicator(
                  onRefresh: _loadMenuItems,
                  child: filtered.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Icon(
                              Icons.fastfood_outlined,
                              size: 48,
                              color: DDartTheme.textMuted(context),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: Text(
                                'No menu items found. Tap "Add Item" to create one!',
                                style: TextStyle(color: textSecondary, fontSize: 13),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _buildMenuItemCard(item);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(CanteenMenuItem item) {
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);
    final accent = DDartTheme.accentText(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: DDartTheme.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: DDartTheme.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 66,
                height: 66,
                color: DDartTheme.cardSubtle(context),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.fastfood, color: DDartTheme.textMuted(context)),
                      )
                    : Icon(Icons.fastfood, color: DDartTheme.textMuted(context)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: item.isAvailable ? textPrimary : textSecondary,
                            decoration:
                                item.isAvailable ? null : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      Text(
                        '₱${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (item.unitDescription.isNotEmpty)
                    Text(
                      item.unitDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _metaTag(context, item.canteen, accent),
                      _metaTag(context, item.category, textSecondary),
                      _metaTag(
                        context,
                        item.isAvailable ? 'In Stock' : 'Sold Out',
                        item.isAvailable ? Colors.green : Colors.redAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        item.isAvailable ? 'Available' : 'Sold Out',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: item.isAvailable,
                          activeThumbColor: DDartTheme.brightGold,
                          activeTrackColor: DDartTheme.primaryMaroon,
                          onChanged: (v) => _toggleAvailability(item, v),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit item',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.edit_outlined, size: 19, color: accent),
                        onPressed: () => _openItemEditor(existing: item),
                      ),
                      IconButton(
                        tooltip: 'Delete item',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaTag(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
