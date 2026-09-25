import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/dashed_stitch.dart';

/// Screen 1 — Home Dashboard
/// Artisanal eco-craft dashboard showcasing rescued fabric impact,
/// stats strip with fabric cutting line dividers, primary transformation CTA,
/// and horizontal recent projects gallery.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Greeting & Brand Mark
                      _buildTopHeader(),

                      const SizedBox(height: 24),

                      // Hero "Swing Tag" Card
                      _buildHeroSwingTagCard(),

                      const SizedBox(height: 20),

                      // Stat Strip (separated by vertical dashed lines, no boxes)
                      _buildStatStrip(),

                      const SizedBox(height: 28),

                      // Primary CTA Button: "Start a transformation"
                      _buildPrimaryCTA(context),

                      const SizedBox(height: 32),

                      // Recent Projects Section Header & Horizontal Scrolling Row
                      _buildRecentProjectsSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation Bar
              _buildBottomNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Row: Greeting text left + Brand Mark & "EcoStitch" right
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good afternoon',
              style: AppTheme.bodySmall(color: AppTheme.inkSoft).copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome back',
              style: AppTheme.headlineSmall(color: AppTheme.ink).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        // Brand Mark (leaf/needle circular badge) + "EcoStitch" in Fraunces
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.greenDeep,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greenDeep.withOpacity(0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.eco_rounded,
                  size: 18,
                  color: AppTheme.cream,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'EcoStitch',
              style: AppTheme.brandWordmark(color: AppTheme.greenDeep),
            ),
          ],
        ),
      ],
    );
  }

  /// Hero "Swing Tag" Card
  /// - Garment swing tag with punch-hole top-left
  /// - Label "FABRIC RESCUED SO FAR" in small caps-free text
  /// - Big Fraunces number "3.2 kg"
  /// - One-line subtitle
  /// - Dashed cream cutting line along the bottom edge
  Widget _buildHeroSwingTagCard() {
    return SwingTagCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Fabric rescued so far',
                  style: AppTheme.labelCapsFree(
                    color: AppTheme.cream.withOpacity(0.85),
                  ).copyWith(
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.greenMid.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.cream.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: AppTheme.cream,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+18% this mo',
                      style: AppTheme.bodySmall(color: AppTheme.cream).copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '3.2 kg',
            style: AppTheme.statHeroNumber(color: AppTheme.cream),
          ),
          const SizedBox(height: 6),
          Text(
            'Equivalent to 4 pairs of denim jeans diverted from landfill.',
            style: AppTheme.bodyMedium(color: AppTheme.cream.withOpacity(0.85)).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  /// Stat Strip below Hero Card
  /// 3 stats side by side (Projects made / Water saved / Garment types),
  /// separated by thin vertical dashed lines, not boxes
  Widget _buildStatStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cream.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.greenSoft.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildStatItem('12', 'Projects made'),
            ),
            const DashedDivider(
              direction: Axis.vertical,
              dashLength: 4,
              dashGap: 3,
              strokeWidth: 1.2,
              color: AppTheme.greenSoft,
            ),
            Expanded(
              child: _buildStatItem('8,400 L', 'Water saved'),
            ),
            const DashedDivider(
              direction: Axis.vertical,
              dashLength: 4,
              dashGap: 3,
              strokeWidth: 1.2,
              color: AppTheme.greenSoft,
            ),
            Expanded(
              child: _buildStatItem('6', 'Garment types'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: AppTheme.statValue(color: AppTheme.greenDeep),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.statLabel(color: AppTheme.inkSoft).copyWith(
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  /// Primary CTA Button: Full width, pill-shaped, greenDeep background, cream text,
  /// label "Start a transformation" with right-pointing arrow icon. Navigates to Capture screen.
  Widget _buildPrimaryCTA(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          context.push('/garment-type');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.greenDeep,
          foregroundColor: AppTheme.cream,
          elevation: 2,
          shadowColor: AppTheme.greenDeep.withOpacity(0.3),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Start a transformation',
              style: AppTheme.buttonText(color: AppTheme.cream).copyWith(
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.cream,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// "Recent projects" section: horizontal scrolling row of rounded-rect cards
  /// with gradient fills and a dashed bottom border, each labeled with placeholder project names.
  Widget _buildRecentProjectsSection() {
    final projects = [
      {
        'title': 'Denim → Tote',
        'subtitle': 'Heavyweight twill',
        'icon': Icons.shopping_bag_outlined,
        'tag': 'Complete',
        'color': const Color(0xFF385E72),
      },
      {
        'title': 'Linen Shirt → Apron',
        'subtitle': 'Breathable weave',
        'icon': Icons.kitchen_outlined,
        'tag': 'In progress',
        'color': const Color(0xFF6B583E),
      },
      {
        'title': 'Wool Scarf → Mittens',
        'subtitle': 'Recycled knit',
        'icon': Icons.pan_tool_outlined,
        'tag': 'Draft',
        'color': const Color(0xFF5A624E),
      },
      {
        'title': 'Canvas Pant → Pouch',
        'subtitle': 'Reinforced seams',
        'icon': Icons.inventory_2_outlined,
        'tag': 'Saved',
        'color': const Color(0xFF4A5568),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent projects',
              style: AppTheme.headlineSmall(color: AppTheme.ink).copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.greenMid,
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View all',
                style: AppTheme.bodySmall(color: AppTheme.greenMid).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: projects.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = projects[index];
              return DashedBottomCard(
                gradient: AppTheme.projectCardGradient,
                borderRadius: 16,
                dashColor: AppTheme.greenSoft,
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              size: 18,
                              color: item['color'] as Color,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.mintTop,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['tag'] as String,
                              style: AppTheme.bodySmall(color: AppTheme.greenDeep).copyWith(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodyMedium(color: AppTheme.ink).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySmall(color: AppTheme.inkSoft).copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Bottom Navigation Bar: Home / Projects / Gallery / Profile
  /// Simple line icons, active tab colored greenDeep, inactive inkSoft
  Widget _buildBottomNavigationBar() {
    final navItems = [
      {'icon': Icons.home_outlined, 'activeIcon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.content_cut_outlined, 'activeIcon': Icons.content_cut_rounded, 'label': 'Projects'},
      {'icon': Icons.photo_library_outlined, 'activeIcon': Icons.photo_library_rounded, 'label': 'Gallery'},
      {'icon': Icons.person_outline_rounded, 'activeIcon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cream,
        border: Border(
          top: BorderSide(
            color: AppTheme.greenSoft.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final isSelected = _selectedNavIndex == index;
              final item = navItems[index];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedNavIndex = index;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? (item['activeIcon'] as IconData) : (item['icon'] as IconData),
                        size: 22,
                        color: isSelected ? AppTheme.greenDeep : AppTheme.inkSoft,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['label'] as String,
                        style: AppTheme.bodySmall(
                          color: isSelected ? AppTheme.greenDeep : AppTheme.inkSoft,
                        ).copyWith(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
