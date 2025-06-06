/**
 * @author Luong Huu Phuc
 * @date 2025/05/05 - 1h07 AM 
 * @file merge_sort_cudalib.cuh 
 * @copyright JoeyOhman
 * \anchor https://github.com/JoeyOhman/GPUMergeSort
 */
#ifndef MERGE_SORT_CUDALIB_CUH__
#define MERGE_SORT_CUDALIB_CUH__

#include <iostream>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#define min_local(a, b) ((a) < (b) ? (a) : (b))

/** 
 * @brief Day la nguong quan trong de co the benchmark duoc den gioi han cua chuong trinh (16384, 32768, 65536,...)
 * @note Ly do boi vi:
 * \note - Tuy vao suc manh cua GPU thi nen set threshold de khong bi vuot qua tai nguyen cua GPU
 * \note - Moi lan goi kernel CUDA la mot cuoc goi ton tai nguyen: kernel phai duoc cau hinh, phan phat luong, dong bo bo nho
 * \note - Neu ta goi kernel cho nhung doan mang qua nho (8, 16, 32,...phan tu) thi chi phi goi kernel con lon hon ca viec sap xep bang CPU tuan tu
 * gay ra overhead tren kernel, gay chiem tai nhieu tai nguyen, vuot qua suc chua cua GPU 
 * 
*/
#define MERGE_PARALLEL_THRESHOLD 32768 
/**
 * @brief Co ban ve kien truc torng GPU
 * @param threadsPerBlock So luong moi thread trong moi khoi (block) - Quyet dinh do song song trong moi block,
 * toi da thuong la 1024 thread/block tuy GPU. Vi du: dim3 threadsPerBlock(16, 16) => Moi block se co 16 x 16 = 256 threads  
 * @param blocksPerGrid So luong block moi grid (luoi) - giup chia task thanh nhieu block nho de GPU xu ly song song
 * Vi du: dim3 blocksPerGrid(32, 32) => Luoi se co 32 x 32 = 1024 blocks
 * \note Tong so thread = blocksPerGrid x threadsPerBlock  
 * \note Cau hinh kernel launch (<<<...>>>) quyet dinh so thread va block khi chay
 */

# ifdef __cplusplus
extern "C" { //Dung khi goi cac ham tu C trong C++ hoac nguoc lai
#endif 

__host__ bool isSorted(long *arr, long n);

/************************** VERSION 1 ***************************/

/**
 * @brief - Cay nhi phan tim kiem duoc su dung tren day so da duoc sap xep tang dan hoac giam dan
 * \brief - Dung de tim so phan tu nho hon val trong pham vi [left, right]
 * 
 * \note Y tuong thuat toan: o moi lan tim kiem tren doan [L, R] thi ban se tim ra phan tu dung giua va so sanh
 * voi phan tu X, vi mang da sap xep theo thu tu nen khi so sanh X voi phan tu dung giua ban co the loai bo di 
 * 1 nua khoang tim kiem, cu nhu vay thi doan ban can tim kiem se giam di 1/2 sau moi lan
 * \note - Vi du mang co 1 ty phan tu thi ban chi can tim kiem 31 lan 
 * \note - Do phuc tap O(logN)    
 * 
 * @return - Tra ve vi tri (index) cua phan tu nho hon de thoa man thu tu tang dan
 */
__device__ int binarySearch(long *arr, int val, int left, int right);

/**
 * @brief Tim vi tri chinh xac cua phan tu `subAux[ownIndex]` trong mang bang cach
 * \brief - Xac dinh xem phan tu do thuoc mang con nao (trai hay phai)
 * \brief - Tim xem bao nhieu phan tu trong mang con lai nho hon no (dung `binarySearch()`)
 * 
 * @return - Tra ve vi tri (index) cua phan tu theo thu tu tang dan 
 * (vi tri do se duoc dung sap xep vao mang arr cuoi cung)
 * 
 * @param subAux Mang chua 2 mang con da sap xep dinh lai nhau 
 * @param ownIndex Vi tri cua phan tu dang xet trong subAux 
 * @param nLeft So luong phan tu o mang trai (Cung la index cua phan tu dau tien cua mang phai)
 * @param nTot  Tong so phan tu(nLeft + mang phai)
 */
__device__ int getIndex(long *subAux, int ownIndex, int nLeft, int nTot);
 
/**
 * @brief Kernel CUDA thuc hien viec hop nhat 2 mang con song song 
 * @details Moi thread xu ly 1 phan tu tu mang phu aux
 * Su dung getIndex() de xac dinh vi tri chinh xac trong mang ket qua arr
 * Ghi gia tri tu aux vao vi tri tuong ung trong arr 
 * @warning Ham nay khong xu ly duoc truong hop mang co phan tu trung nhau 
 * do trong ham nay dung getIndex() co su dung binarySearch(), von chi chinh xac 
 * khi moi phan tu la duy nhat de co the xac dinh vi tri chen
 * @note Ham nay duoc goi boi mergeSort()
 * @param arr Mang sau khi da tim duoc chinh xac index thi se cho vao
 * @param aux Mang tam, dung de luu ket qua trung gian qua tung vong gop (merge)
 * @param left vi tri ben trai cua mang 
 * @param mid vi tri o giua cua mang 
 * @param right vi tri ben phai cua mang
 */
__global__ void mergeKernel(long *arr, long *aux, int left, int mid, int right);

/**
 * @brief Merge tuan tu de tranh overhead khi so luong phan tu nho khi song song
 * @note Ham nay duoc goi boi mergeSort()
 */
__host__ __device__ void merge(long *arr, long *aux, int left, int mid, int right);

/**
 * @brief Dieu phoi qua trinh Bottom-Up Merge Sort  
 * @note Moi thread xu ly mot cap mang con co kich thuoc currentSize. Xac dinh chi so left, mid, right
 * cho mang hien tai. Neu kich thuoc mang con lon hon 1 nguong nhat dinh, goi mergeKernel de hop nhat song song
 * Nguoc lai, neu mang be hon nguong nhat dinh, dung merge tuan tu
 * @param arr Mang chua phan tu sau khi da sap xep 
 * @param aux Mang tam, mang chua ket qua trung gian sau moi lan merge 
 * @param afterSize Do dai mang sau khi gop 2 mang con dang can merge do lai (afterSize = 2 * currentSize)
 * @param currentSize Kich thuoc hien tai cua mang con dang merge (1 phan tu, 2 phan tu, 4 phan tu,...)
 * \note - Ham nay duoc goi boi mergeSortGPU()
 * \note - Moi thread dam nhiem 1 lan merge
 */
__global__ void mergeSort_coordinate(long *arr, long *aux, int currentSize, int n, int afterSize);

/**
 * @brief MergeSort tren GPU
 * \brief - Ham nay se chia mang ban dau thanh cac mang co kich thuoc tu 1 phan tu/mang
 * \brief - Sau do chay vong lap voi kich thuoc phan tu trong mang tang dan (1, 2, 4, 8,...) va chieu rong mang sau khi gop cung tang (2, 4, 8,..)
 * \brief - Trong moi vong lap, goi kernel de thuc hien gop (merge) cac phan tu lai
 * 
 * @param arr Mang tu CPU -> chuyen qua GPU de thuc hien
 * @param n So luong phan tu can merge sort
 * 
 * \note - Cap bo nho thong nhat (unified memory) cho deviceArr va auxArr, cho phep CPU & GPU cung truy cap
 * \note - Cach nay giup khong can copy qua lai thu cong tu CPU qua GPU (cudaMemcpy())
  \note - CPU <------> |   Unified Memory    | <------> GPU
 */
void mergeSortGPU(long *arr, int n);


/************************** VERSION 2 ***************************/

/**
 * @brief Ham tinh toan chi so thread trong kernel hien tai
 */
__device__ unsigned int getIndex_kernel(dim3 *threads, dim3 *blocks);

__global__ void gpu_mergeSort_ver2(long *arr, long *aux, long n, long afterSize, long slices, dim3 *threads, dim3 *blocks);

/**
 * @brief Duoc goi boi gpu_mergeSort_ver2()
 */
__device__ void gpu_bottomUpMerge_ver2(long *arr, long *aux, long left, long mid, long right);

void mergeSortGPU_ver2(long *arr, long n, dim3 threadsPerBlock, dim3 blocksPerGrid);

#ifdef __cplusplus
}
#endif 

#endif //MERGE_SORT_CUDALIB_CUH__