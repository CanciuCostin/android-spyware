# Accessibility Testing Checklist

This checklist provides manual testing steps to verify WCAG 2.1 AA compliance for the EagleSpy V5 frontend.

## Table of Contents

1. [Keyboard Navigation](#keyboard-navigation)
2. [Screen Reader Testing](#screen-reader-testing)
3. [Visual Accessibility](#visual-accessibility)
4. [Form Accessibility](#form-accessibility)
5. [Interactive Elements](#interactive-elements)
6. [Content Structure](#content-structure)
7. [ARIA Usage](#aria-usage)
8. [Performance & Core Web Vitals](#performance--core-web-vitals)

---

## Keyboard Navigation

### Basic Navigation
- [ ] **Tab key**: Navigate forward through all interactive elements
- [ ] **Shift+Tab**: Navigate backward through interactive elements
- [ ] **Enter/Space**: Activate buttons and links
- [ ] **Escape**: Close modals, dialogs, and command palette
- [ ] **Arrow keys**: Navigate within menus, command palette, and lists

### Skip Link
- [ ] Press Tab on page load
- [ ] "Skip to main content" link appears visually
- [ ] Pressing Enter skips navigation and focuses main content
- [ ] Skip link works on all pages

### Focus Indicators
- [ ] All interactive elements show visible focus indicator
- [ ] Focus indicator has sufficient contrast (min 3:1 against background)
- [ ] Focus order is logical and follows visual layout
- [ ] Focus is not trapped unintentionally
- [ ] No focus outline on mouse click (only keyboard focus)

### Command Palette (Cmd/Ctrl+K)
- [ ] Opens with Cmd+K (Mac) or Ctrl+K (Windows/Linux)
- [ ] Can be closed with Escape
- [ ] Arrow keys navigate through commands
- [ ] Enter activates selected command
- [ ] Focus returns to trigger element when closed

### Modals & Dialogs
- [ ] Focus moves to modal when opened
- [ ] Focus is trapped within modal (Tab cycles through modal elements)
- [ ] Escape closes modal
- [ ] Focus returns to trigger element when closed
- [ ] Modal backdrop closes modal when clicked

---

## Screen Reader Testing

### Tools to Use
- **Windows**: NVDA (free) or JAWS
- **macOS**: VoiceOver (built-in, Cmd+F5)
- **Mobile**: TalkBack (Android) or VoiceOver (iOS)

### Test Scenarios

#### Page Structure
- [ ] Page title is announced correctly
- [ ] Landmark regions are identified (banner, navigation, main, contentinfo)
- [ ] Headings follow logical hierarchy (h1 → h2 → h3)
- [ ] Skip link is announced first

#### Navigation
- [ ] All links have descriptive text
- [ ] Current page/location is announced
- [ ] Breadcrumbs are navigable and contextual
- [ ] Sidebar/navigation items have clear labels

#### Forms
- [ ] Form fields have associated labels
- [ ] Required fields are announced
- [ ] Input types are identified (text, email, number, etc.)
- [ ] Error messages are announced when validation fails
- [ ] Helper text is associated with inputs

#### Interactive Components
- [ ] Button purposes are clear from labels
- [ ] Icon buttons have aria-label attributes
- [ ] Loading states are announced
- [ ] Disabled states are announced
- [ ] Toast notifications are announced automatically

#### Live Regions
- [ ] Activity feed updates are announced
- [ ] Command status changes are announced
- [ ] Real-time data updates are announced appropriately
- [ ] Not too many announcements (avoid overwhelming user)

#### Images & Icons
- [ ] Decorative icons have aria-hidden="true"
- [ ] Informative images have descriptive alt text
- [ ] Icons with semantic meaning have labels

---

## Visual Accessibility

### Color Contrast
Use Chrome DevTools or online tools to verify:
- [ ] Normal text (< 18pt): Minimum 4.5:1 contrast ratio
- [ ] Large text (≥ 18pt or bold ≥ 14pt): Minimum 3:1 contrast ratio
- [ ] Interactive elements: Minimum 3:1 contrast ratio
- [ ] Focus indicators: Minimum 3:1 contrast ratio
- [ ] Information not conveyed by color alone

### Test Pages/Components
- [ ] Dashboard cards and metrics
- [ ] Device status badges
- [ ] Form inputs and labels
- [ ] Buttons (all variants: primary, secondary, ghost, danger)
- [ ] Toast notifications (success, error, warning, info)
- [ ] Activity feed items
- [ ] Data visualizations (charts must have patterns/textures)

### Responsive Text
- [ ] Text can be resized up to 200% without horizontal scrolling
- [ ] Text reflows and remains readable
- [ ] No text is cut off or overlapping

### High Contrast Mode (Windows)
- [ ] Enable Windows High Contrast mode
- [ ] All borders are visible
- [ ] Focus indicators are visible
- [ ] Icons and UI elements are distinguishable
- [ ] No information is lost

### Reduced Motion
- [ ] Test with `prefers-reduced-motion` enabled
- [ ] Animations are reduced or disabled
- [ ] Page transitions are simplified
- [ ] Essential motion is maintained

To test:
- **macOS**: System Preferences → Accessibility → Display → Reduce motion
- **Windows**: Settings → Ease of Access → Display → Show animations
- **Browser**: Chrome DevTools → Rendering → Emulate CSS prefers-reduced-motion

---

## Form Accessibility

### All Form Pages
- [ ] Settings page forms
- [ ] Device command forms
- [ ] Search/filter forms

### For Each Form:
- [ ] Every input has a visible label
- [ ] Labels are properly associated (htmlFor/id)
- [ ] Required fields are marked (asterisk + aria-required)
- [ ] Error messages appear adjacent to invalid fields
- [ ] Error messages have role="alert" or aria-live
- [ ] Errors are announced by screen readers
- [ ] Helper text is associated with aria-describedby
- [ ] Field groups use fieldset and legend
- [ ] Validation occurs on blur or submit (not on every keystroke)

---

## Interactive Elements

### Buttons
- [ ] All buttons have descriptive labels
- [ ] Icon-only buttons have aria-label
- [ ] Loading state is announced (aria-busy)
- [ ] Disabled state is announced (aria-disabled)
- [ ] Button purpose is clear from context

### Links
- [ ] Link text describes destination
- [ ] Avoid "click here" or generic text
- [ ] External links indicated (icon or text)
- [ ] Links in new tabs announced (aria-label or title)

### Cards & Clickable Areas
- [ ] Clickable cards have proper semantics (article, button, or link)
- [ ] Card actions are keyboard accessible
- [ ] Click target is at least 44×44 CSS pixels (mobile)
- [ ] Interactive areas have visible hover/focus states

### Tabs
- [ ] Tab list has role="tablist"
- [ ] Each tab has role="tab"
- [ ] Tab panels have role="tabpanel"
- [ ] aria-selected indicates active tab
- [ ] Arrow keys navigate between tabs
- [ ] Tab key moves focus out of tab list

---

## Content Structure

### Headings
- [ ] One h1 per page (page title)
- [ ] Heading levels don't skip (no h1 → h3)
- [ ] Headings accurately describe sections
- [ ] Headings are not used for styling alone

### Landmarks
- [ ] header or role="banner"
- [ ] nav or role="navigation" 
- [ ] main or role="main"
- [ ] aside or role="complementary"
- [ ] footer or role="contentinfo"
- [ ] Landmarks have aria-label if multiple of same type

### Lists
- [ ] Lists use ul, ol, or role="list"
- [ ] Navigation menus use proper list structure
- [ ] Activity feed uses semantic markup

---

## ARIA Usage

### Verify Correct ARIA Implementation

#### ARIA Labels
- [ ] aria-label provides accessible name when no visible label
- [ ] aria-labelledby references visible label element
- [ ] aria-describedby provides additional context

#### ARIA States
- [ ] aria-expanded on collapsible elements
- [ ] aria-pressed on toggle buttons
- [ ] aria-selected on tabs and options
- [ ] aria-current on navigation items
- [ ] aria-busy on loading elements
- [ ] aria-disabled on disabled elements

#### ARIA Live Regions
- [ ] aria-live="polite" for non-urgent updates
- [ ] aria-live="assertive" for urgent notifications (toasts)
- [ ] aria-atomic="true" when entire region should be announced
- [ ] role="alert" for error messages
- [ ] role="status" for status updates

#### ARIA Roles
- [ ] role="dialog" on modals
- [ ] role="alertdialog" on confirmation dialogs
- [ ] role="menu" on dropdown menus
- [ ] role="feed" on activity feeds
- [ ] role="article" on feed items

### Common ARIA Mistakes to Avoid
- [ ] No conflicting roles on native elements
- [ ] No aria-label on non-interactive elements
- [ ] No aria-hidden on focusable elements
- [ ] No redundant ARIA (e.g., role="button" on <button>)

---

## Performance & Core Web Vitals

### Lighthouse Audit
1. Open Chrome DevTools
2. Navigate to Lighthouse tab
3. Select "Desktop" or "Mobile"
4. Check all categories
5. Click "Generate report"

### Target Scores
- [ ] **Performance**: 90+ (green)
- [ ] **Accessibility**: 95+ (green)
- [ ] **Best Practices**: 95+ (green)
- [ ] **SEO**: 90+ (green)

### Core Web Vitals
- [ ] **LCP** (Largest Contentful Paint): < 2.5s
- [ ] **FID** (First Input Delay): < 100ms
- [ ] **CLS** (Cumulative Layout Shift): < 0.1

### Performance Checks
- [ ] Images are optimized (WebP format)
- [ ] Code splitting is working (check bundle sizes)
- [ ] Lazy loading implemented for heavy components
- [ ] No layout shifts during load
- [ ] Smooth animations (60 FPS)
- [ ] Fast initial page load (< 3s on 3G)

---

## Automated Testing Tools

### Browser Extensions
- **axe DevTools**: Automated accessibility testing
- **WAVE**: Visual feedback on accessibility issues
- **Lighthouse**: Built into Chrome DevTools

### During Development
- ESLint with jsx-a11y plugin (already configured)
- TypeScript strict mode
- React DevTools for component inspection

### CI/CD Integration (Future)
- Lighthouse CI for performance regression testing
- Pa11y for automated accessibility checks
- Percy/Chromatic for visual regression

---

## Common Issues & Solutions

### Issue: Focus outline not visible
**Solution**: Check CSS has proper focus-visible styles

### Issue: Screen reader not announcing changes
**Solution**: Add aria-live region or role="alert"

### Issue: Modal focus not trapped
**Solution**: Verify FocusTrap component is implemented

### Issue: Form errors not announced
**Solution**: Add role="alert" and aria-describedby

### Issue: Color contrast fails
**Solution**: Adjust color values, test with contrast checker

### Issue: Tab order is illogical
**Solution**: Reorder DOM elements or use tabindex appropriately

---

## Testing Workflow

### For Each New Feature
1. ✅ Code with accessibility in mind (semantic HTML, ARIA)
2. ✅ Run ESLint to catch common issues
3. ✅ Manual keyboard navigation test
4. ✅ Test with screen reader (basic flow)
5. ✅ Check color contrast
6. ✅ Run Lighthouse audit
7. ✅ Fix any issues found
8. ✅ Document any known limitations

### Before Each Release
1. ✅ Complete full keyboard navigation test
2. ✅ Complete screen reader test (critical flows)
3. ✅ Test with reduced motion enabled
4. ✅ Test with Windows High Contrast mode
5. ✅ Run Lighthouse on all major pages
6. ✅ Verify Core Web Vitals meet targets
7. ✅ Review and update documentation

---

## Known Limitations

### Current Limitations (to be documented)
- [ ] Map component may have limited keyboard navigation
- [ ] Complex charts may require alternative text descriptions
- [ ] Real-time updates may be overwhelming for screen readers
- [ ] Mobile touch gestures may need documentation

### Planned Improvements
- [ ] Add skip navigation for complex data tables
- [ ] Improve chart accessibility with data tables
- [ ] Add keyboard shortcuts documentation page
- [ ] Implement focus management for route changes

---

## Resources

### WCAG Guidelines
- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [WCAG 2.1 Understanding Docs](https://www.w3.org/WAI/WCAG21/Understanding/)

### Testing Tools
- [axe DevTools](https://www.deque.com/axe/devtools/)
- [WAVE Browser Extension](https://wave.webaim.org/extension/)
- [NVDA Screen Reader](https://www.nvaccess.org/download/)
- [Chrome DevTools Lighthouse](https://developers.google.com/web/tools/lighthouse)

### Learning Resources
- [The A11Y Project](https://www.a11yproject.com/)
- [MDN Web Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility)
- [WebAIM Articles](https://webaim.org/articles/)
- [Inclusive Components](https://inclusive-components.design/)

---

## Sign-Off

### Tested By: _______________
### Date: _______________
### Version: _______________

### Summary
- Total Issues Found: ___
- Critical Issues: ___
- Medium Issues: ___
- Minor Issues: ___
- Status: ☐ Pass ☐ Pass with notes ☐ Fail
