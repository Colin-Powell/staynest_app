import re

with open('lib/screens/dashboard/landlord_properties_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """          } else {
            final fallbackViews =
                120 + (widget.property.id.hashCode % 800).abs();
            final fallbackSaves = 5 + (widget.property.id.hashCode % 50).abs();
            _viewsCount = _formatCount(fallbackViews);
            _savesCount = _formatCount(fallbackSaves);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final fallbackViews = 120 + (widget.property.id.hashCode % 800).abs();
          final fallbackSaves = 5 + (widget.property.id.hashCode % 50).abs();
          _viewsCount = _formatCount(fallbackViews);
          _savesCount = _formatCount(fallbackSaves);
        });
      }
    }"""

replacement = """          } else {
            _viewsCount = '0';
            _savesCount = '0';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _viewsCount = '0';
          _savesCount = '0';
        });
      }
    }"""

content = content.replace(target, replacement)

with open('lib/screens/dashboard/landlord_properties_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed fake views in landlord_properties_page.dart")
