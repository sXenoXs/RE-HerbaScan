# Manual Testing Guide - Phase 5
## Hybrid Grad-CAM/CAM System Testing

**Date**: October 29, 2025  
**Purpose**: Guide for manual testing of the hybrid Grad-CAM/CAM implementation

---

## 📋 **Prerequisites**

### **Test Environment Setup**
- [ ] Physical Android/iOS device (recommended)
- [ ] Or Android/iOS emulator
- [ ] 10 plant images prepared (different species)
- [ ] Network connectivity (WiFi/4G)
- [ ] Ability to enable airplane mode

### **Test Images**
Prepare 10 plant images with:
- Different plant species
- Mix of good and poor quality
- Different lighting conditions
- Different backgrounds
- Various image sizes

---

## 🔬 **Task 5.1: Online Grad-CAM Testing**

### **Test Scenario 1: Basic Functionality**
**Steps**:
1. Launch app
2. Navigate to Scan screen
3. Ensure WiFi/data is ON
4. Capture or pick a plant image
5. Wait for processing
6. Navigate to Results screen

**Expected Results**:
- ✅ Image processes successfully
- ✅ Predictions displayed
- ✅ Heatmap displays in GradCAM tab
- ✅ Method badge shows "🌐 Online (Grad-CAM)" (green badge)
- ✅ Processing time < 5 seconds

**Record**:
- Processing time: ______ seconds
- Heatmap quality: Good / Fair / Poor
- Method badge: Correct / Incorrect
- Any errors: _________________

---

### **Test Scenario 2: Quality Validation**
**Steps**:
1. Process same image with Python Grad-CAM (if available)
2. Compare heatmaps side-by-side
3. Note similarities and differences

**Expected Results**:
- ✅ Heatmap quality >90% similar to Python output
- ✅ Relevant features highlighted
- ✅ Overlay blending works correctly
- ✅ Jet colormap applied correctly

**Record**:
- Visual similarity: ______ %
- Features highlighted: Yes / No
- Colormap: Correct / Incorrect

---

### **Test Scenario 3: Performance Testing**
**Steps**:
1. Process 10 different plant images
2. Record processing time for each
3. Calculate average

**Expected Results**:
- ✅ Average processing time < 5 seconds
- ✅ No timeout errors
- ✅ Consistent performance

**Record**:
| Image | Time (s) | Status |
|-------|----------|--------|
| 1     | _____    | ✅/❌  |
| 2     | _____    | ✅/❌  |
| ...   | ...      | ...    |
| 10    | _____    | ✅/❌  |
| **Average** | **_____** | |

---

### **Test Scenario 4: Error Handling**
**Steps**:
1. Test with server down:
   - Disconnect from internet OR
   - Turn off WiFi/data
   - Process image
2. Test with slow network:
   - Use network throttling (if available)
   - Process image
3. Test with invalid image:
   - Use corrupted/unsupported image
   - Process image

**Expected Results**:
- ✅ Graceful fallback to offline mode
- ✅ Clear error messages (if applicable)
- ✅ No crashes
- ✅ Fallback badge shows correctly

**Record**:
- Server down: Fallback works / Fails / Crashes
- Slow network: Timeout handled / Not handled
- Invalid image: Error handled / Crashes

---

## 📴 **Task 5.2: Offline CAM Testing**

### **Test Scenario 1: Basic Functionality (Airplane Mode)**
**Steps**:
1. Enable airplane mode
2. Launch app
3. Navigate to Scan screen
4. Capture or pick a plant image
5. Wait for processing
6. Navigate to Results screen

**Expected Results**:
- ✅ Image processes successfully (offline)
- ✅ Predictions displayed
- ✅ Heatmap displays in GradCAM tab
- ✅ Method badge shows "📴 Offline (CAM)" (blue badge)
- ✅ Processing time < 2 seconds
- ✅ Works 100% offline (no network required)

**Record**:
- Processing time: ______ seconds
- Heatmap smooth: Yes / No (no huge pixels)
- Method badge: Correct / Incorrect
- Works offline: Yes / No

---

### **Test Scenario 2: Heatmap Quality**
**Steps**:
1. Process same 10 images in offline mode
2. Inspect heatmaps for:
   - Smooth upscaling (no pixelation)
   - Proper bilinear interpolation
   - Jet colormap applied correctly
   - Overlay blending works

**Expected Results**:
- ✅ Smooth heatmap (no huge pixels)
- ✅ Proper upscaling from 7×7 to 224×224
- ✅ Colormap applied correctly
- ✅ Overlay blends smoothly

**Record**:
| Image | Smooth | Colormap | Overlay | Quality |
|-------|--------|----------|---------|---------|
| 1     | ✅/❌  | ✅/❌    | ✅/❌   | Good/Fair/Poor |
| ...   | ...    | ...      | ...     | ...     |

---

### **Test Scenario 3: Performance Testing**
**Steps**:
1. Process 10 images in airplane mode
2. Record processing time for each
3. Calculate average

**Expected Results**:
- ✅ Average processing time < 2 seconds
- ✅ Consistent performance
- ✅ No crashes

**Record**:
| Image | Time (s) | Status |
|-------|----------|--------|
| 1     | _____    | ✅/❌  |
| ...   | ...      | ...    |
| **Average** | **_____** | |

---

### **Test Scenario 4: Reliability Testing**
**Steps**:
1. Process 50 consecutive scans in airplane mode
2. Monitor for:
   - Memory leaks
   - Performance degradation
   - Crashes
   - Consistency

**Expected Results**:
- ✅ No crashes
- ✅ No memory leaks
- ✅ Consistent performance
- ✅ All scans complete successfully

**Record**:
- Total scans: 50
- Successful: ______
- Failed: ______
- Crashes: ______
- Memory usage: Stable / Increasing

---

## 🔄 **Task 5.3: Adaptive Switching Testing**

### **Test Scenario 1: Online → Offline Fallback**
**Steps**:
1. Start with WiFi/data ON
2. Begin processing an image
3. **During processing**, disconnect internet (airplane mode)
4. Wait for completion
5. Check result screen

**Expected Results**:
- ✅ Automatic fallback to offline mode
- ✅ Processing completes successfully
- ✅ Method badge shows "📴 Offline (Fallback)" (orange badge)
- ✅ `fallback_used` flag is true
- ✅ No crashes or errors

**Record**:
- Fallback triggered: Yes / No
- Badge correct: Yes / No
- Crashes: Yes / No

---

### **Test Scenario 2: Connectivity Detection**
**Steps**:
1. Check connectivity status:
   - WiFi ON → Should detect online
   - WiFi OFF → Should detect offline
   - Airplane mode → Should detect offline
2. Test rapid connectivity changes
3. Verify method badge updates correctly

**Expected Results**:
- ✅ Connectivity detection accurate
- ✅ Method badge reflects current mode
- ✅ No false positives/negatives

**Record**:
| Network State | Detected As | Correct |
|---------------|-------------|---------|
| WiFi ON       | Online      | ✅/❌   |
| WiFi OFF      | Offline     | ✅/❌   |
| Airplane Mode | Offline     | ✅/❌   |

---

### **Test Scenario 3: Seamless Switching**
**Steps**:
1. Test various connectivity change scenarios:
   - Online → Offline (during scan)
   - Offline → Online (during scan)
   - Rapid changes
2. Verify no data loss
3. Verify no crashes

**Expected Results**:
- ✅ Seamless transitions
- ✅ No data loss
- ✅ No crashes
- ✅ User experience remains smooth

**Record**:
- Seamless: Yes / No
- Data loss: Yes / No
- Crashes: Yes / No

---

## 📊 **Task 5.4: Performance Testing**

### **Test Scenario 1: Memory Usage**
**Steps**:
1. Monitor memory before scan
2. Process 10 scans (online)
3. Monitor memory after scans
4. Process 10 scans (offline)
5. Monitor memory again
6. Check for memory leaks

**Expected Results**:
- ✅ No significant memory increase
- ✅ No memory leaks
- ✅ Stable memory usage

**Record**:
- Initial memory: ______ MB
- After online: ______ MB
- After offline: ______ MB
- Memory leak: Yes / No

---

### **Test Scenario 2: Stress Testing**
**Steps**:
1. Process 50 consecutive scans
2. Mix of online/offline
3. Monitor:
   - Performance consistency
   - Memory usage
   - Crashes
   - Errors

**Expected Results**:
- ✅ Consistent performance
- ✅ No crashes
- ✅ No errors
- ✅ Stable memory

**Record**:
- Total scans: 50
- Successful: ______
- Average time: ______ s
- Crashes: ______
- Memory stable: Yes / No

---

## 🎨 **Task 5.5: UI/UX Testing**

### **Test Scenario 1: Method Badge Display**
**Steps**:
1. Process images in online mode
2. Process images in offline mode
3. Process images with fallback
4. Check badge display:
   - Color
   - Icon
   - Text
   - Placement

**Expected Results**:
- ✅ Badge shows correctly
- ✅ Colors correct (green/blue/orange)
- ✅ Icons correct
- ✅ Text readable
- ✅ Placement appropriate

**Record**:
| Mode | Badge Color | Icon | Text | Correct |
|------|-------------|------|------|---------|
| Online | Green | ☁️ | Online | ✅/❌ |
| Offline | Blue | 📴 | Offline | ✅/❌ |
| Fallback | Orange | ⚠️ | Fallback | ✅/❌ |

---

### **Test Scenario 2: Heatmap Display**
**Steps**:
1. Process images in both modes
2. Check heatmap display:
   - Renders from bytes
   - Overlay works
   - Opacity slider works
   - Show/hide toggle works
   - Legend displays

**Expected Results**:
- ✅ Heatmap renders correctly
- ✅ Overlay blends properly
- ✅ Controls work smoothly
- ✅ Legend clear and accurate

**Record**:
- Rendering: Works / Broken
- Overlay: Works / Broken
- Controls: Work / Broken
- Legend: Clear / Unclear

---

## 📝 **Test Results Template**

### **Test Session: [Date]**

**Tester**: _________________  
**Device**: _________________  
**OS Version**: _________________  
**App Version**: _________________

#### **Online Grad-CAM Tests**
- Tests run: ______
- Passed: ______
- Failed: ______
- Average time: ______ s
- Quality rating: ______ / 10

#### **Offline CAM Tests**
- Tests run: ______
- Passed: ______
- Failed: ______
- Average time: ______ s
- Smooth heatmap: Yes / No

#### **Adaptive Tests**
- Fallback tests: ______
- Successful: ______
- Badge accuracy: ______ %
- Seamless switching: Yes / No

#### **Issues Found**
1. _________________
2. _________________
3. _________________

#### **Recommendations**
1. _________________
2. _________________
3. _________________

---

## ✅ **Acceptance Checklist**

### **Functional**
- [ ] Online mode works correctly
- [ ] Offline mode works correctly
- [ ] Adaptive switching works
- [ ] Method badges accurate

### **Performance**
- [ ] Online: <5 seconds average
- [ ] Offline: <2 seconds average
- [ ] No memory leaks
- [ ] Consistent performance

### **Quality**
- [ ] Heatmap quality acceptable
- [ ] Smooth display (no pixelation)
- [ ] Accurate method badges

### **User Experience**
- [ ] Smooth transitions
- [ ] Clear indicators
- [ ] User-friendly errors

---

*Last Updated: October 29, 2025*

