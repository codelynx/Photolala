# Cache Statistics Guide

## How to Test Cache Effectiveness

### Keyboard Shortcuts
- **S** - Print cache statistics (in browser view)
- **R** - Reset cache statistics (in browser view)

### Testing Steps

1. **First Load Test (Cold Cache)**
   - Open Photolala
   - Press **R** to reset statistics
   - Navigate to a folder with many photos
   - Scroll through all thumbnails
   - Open preview and navigate through several images
   - Press **S** to see statistics

2. **Second Load Test (Warm Cache)**
   - Navigate away and back to the same folder
   - Scroll through thumbnails again
   - Open preview and view same images
   - Press **S** to see updated statistics

### Understanding the Output

```
📊 ========== PHOTOMANAGER CACHE STATISTICS ==========
📸 Images:
   • Cache hits: 45         ← Images loaded from memory (fast)
   • Cache misses: 5        ← Images loaded from disk (slow)
   • Hit rate: 90.0%        ← Higher is better
   • Current cache count: 50
   • Cache limit: 256       ← Dynamic based on device memory

🖼️ Thumbnails:
   • Cache hits: 180        ← Thumbnails from memory
   • Cache misses: 20       ← Thumbnails generated/loaded
   • Hit rate: 90.0%

💾 Disk Operations:
   • Disk reads: 25         ← File system reads
   • Disk writes: 20        ← New thumbnails saved

⏱️ Performance:
   • Total operations: 50
   • Average load time: 0.125s
   • Total time spent loading: 6.250s

💻 Memory:
   • Process memory: 245.3MB
   • Cache memory budget: 2048MB
```

### What to Look For

1. **Hit Rates**: Should increase significantly on second load
   - First load: Expect 0% (cold cache)
   - Second load: Should be 80-100%

2. **Load Times**: 
   - Cache hits: <0.001s
   - Cache misses: 0.1-1.0s depending on image size
   - Thumbnail generation: 0.1-0.3s

3. **Memory Usage**: Should stay well below device limits
   - Monitor process memory vs cache budget
   - Cache automatically evicts when approaching limits

### Console Logs

Look for these patterns in console:
- ✅ CACHE HIT - Fast path, no disk access
- ❌ CACHE MISS - Slower, requires disk read
- 💾 DISK READ - File system access
- 🔨 GENERATING NEW THUMBNAIL - First time thumbnail creation
- 📊 MD5 computation - Currently expensive, needs optimization

### Performance Tips

1. **Prefetching**: Adjacent images are preloaded automatically
2. **Scrolling**: Thumbnails prefetch as you scroll
3. **Cache Size**: Automatically sized to 25% of physical memory
4. **Persistence**: Thumbnails cached to disk permanently